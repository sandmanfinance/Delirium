/*
                    ___                                     ___           ___                   
     _____         /\__\                                   /\__\         /\  \                  
    /::\  \       /:/ _/_                     ___         /:/ _/_        \:\  \         ___     
   /:/\:\  \     /:/ /\__\                   /\__\       /:/ /\  \        \:\  \       /\__\    
  /:/  \:\__\   /:/ /:/ _/_   ___     ___   /:/__/      /:/ /::\  \   ___ /::\  \     /:/  /    
 /:/__/ \:|__| /:/_/:/ /\__\ /\  \   /\__\ /::\  \     /:/__\/\:\__\ /\  /:/\:\__\   /:/__/     
 \:\  \ /:/  / \:\/:/ /:/  / \:\  \ /:/  / \/\:\  \__  \:\  \ /:/  / \:\/:/  \/__/  /::\  \     
  \:\  /:/  /   \::/_/:/  /   \:\  /:/  /   ~~\:\/\__\  \:\  /:/  /   \::/__/      /:/\:\  \    
   \:\/:/  /     \:\/:/  /     \:\/:/  /       \::/  /   \:\/:/  /     \:\  \      \/__\:\  \   
    \::/  /       \::/  /       \::/  /        /:/  /     \::/  /       \:\__\          \:\__\  
     \/__/         \/__/         \/__/         \/__/       \/__/         \/__/           \/__/  

*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/*
    ERROR REF
    ---------
    E1: presale hasn't started yet, good things come to those that wait
    E2: presale has ended, come back next time!
    E3: No more Delight remains!
    E4: No more Delight left!
    E5: not enough usdc provided
    E6: Delight Presale hardcap reached
    E7: user has already purchased too much delight
    E8: user cannot purchase 0 delight
    E9: cannot change start block if sale has already started
    E10: cannot set start block in the past
    E11: can only mint once!
    E12: start block has to be less than end block
    E13: new blocks cant be less than 3 days
*/

contract DelightToken is ERC20('DELIGHT', 'DELIGHT'), ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    address constant presaleAddress = 0x6D9518bd44fce1ee2EF8d7E3090fBA60304A4ceA;
    
    IERC20 public USDC = IERC20(0x1092eE157Cc686972aC025C798343bed573D11Be);
    
    IERC20 delightToken = IERC20(address(this));

    uint256 public constant delightPerAccountMaxTotal = 500 * (10 ** 18); // 500 delight

    uint256 public constant delightMaximumSupply = 75 * (10 ** 3) * (10 ** 18); //75,000k presale public

    uint256 public delightRemaining = delightMaximumSupply;
    
    uint256 public salePriceE35 = 10 * (10 ** 33); // 10 usdc

    uint256 public maxHardCap = 750 * (10 ** 3) * (10 ** 6); // 750,000 usdc

    uint256 public constant oneHourMatic = 1500;
    uint256 public constant minDurationPresale = oneHourMatic * 24 * 3; // 3 days


    uint256 public startBlock;
    
    uint256 public endBlock;

    bool hasMintedForL1;

    mapping(address => uint256) public userDelightTotally;

    event StartBlockChanged(uint256 newStartBlock, uint256 newEndBlock);
    event DelightPurchased(address sender, uint256 usdcSpent, uint256 delightReceived);
    event MintDelightForSandManL1(uint256 amountToMint);


    constructor(uint256 _startBlock, uint256 _endBlock) {
        startBlock  = _startBlock;
        endBlock    = _endBlock;
        _mint(address(this), delightMaximumSupply);
    }
    

    function buyDelight(uint256 _usdcSpent) external nonReentrant {
        require(block.number >= startBlock, "E1");
        require(block.number < endBlock, "E2");
        require(delightRemaining > 0, "E3");
        require(delightToken.balanceOf(address(this)) > 0, "E4");
        require(_usdcSpent > 0, "E5");
        require(_usdcSpent <= maxHardCap, "E6");
        // require(userDelightTotally[msg.sender] <= delightPerAccountMaxTotal, "E7");

        uint256 delightPurchaseAmount = (_usdcSpent * (10 ** 12) * salePriceE35) / 1e35;

        // if we dont have enough left, give them the rest.
        if (delightRemaining < delightPurchaseAmount){
            delightPurchaseAmount = delightRemaining;
            _usdcSpent = ((delightPurchaseAmount * salePriceE35) / 1e33 ) / 1e12;
        }
        

        require(delightPurchaseAmount > 0, "E8");

        // shouldn't be possible to fail these asserts.
        assert(delightPurchaseAmount <= delightRemaining);
        assert(delightPurchaseAmount <= delightToken.balanceOf(address(this)));
        
        //send delight to user
        delightToken.safeTransfer(msg.sender, delightPurchaseAmount);
        // send usdc to presale address
    	USDC.safeTransferFrom(msg.sender, address(presaleAddress), _usdcSpent);

        delightRemaining = delightRemaining - delightPurchaseAmount;
        userDelightTotally[msg.sender] = userDelightTotally[msg.sender] + delightPurchaseAmount;

        emit DelightPurchased(msg.sender, _usdcSpent, delightPurchaseAmount);

    }

    function setStartBlock(uint256 _newStartBlock, uint256 _newEndBlock) external onlyOwner {
        require(block.number < startBlock, "E9");
        require(block.number < _newStartBlock, "E10");
        require(_newStartBlock < _newEndBlock, "E9");
        require((_newEndBlock - _newStartBlock) > minDurationPresale, "E13");

        startBlock = _newStartBlock;
        endBlock   = _newEndBlock;

        emit StartBlockChanged(_newStartBlock, _newEndBlock);
    }

    // this method wil be call  4 hs before farming end once!
    function mintDelightForSandManL1(uint256 amountToMint, address presaleVipAddress) external onlyOwner {
        require(!hasMintedForL1, "E11");
        require(amountToMint > 0);

        hasMintedForL1 = true;
        _mint(presaleVipAddress, amountToMint);
        emit MintDelightForSandManL1(amountToMint);
    }

}