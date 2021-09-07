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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



/*
    ERROR REF
    ---------
    E1: Delight cannot be equal to delirium
    E2: Delight still sane
    E3: Not Enough delight tokens in contract for swap
    E4: Failed sending sandman token
    E5: can only send excess delight to dead address after presale has ended
    E6: can only burn unsold presale once!
    E7: cannot set start block in the past!
    E8: _DelightAddress cannot be the zero address
    E9: fee address cannot partake in presale
    E10: presale hasn't started yet, good things come to those that wait
    E11: presale has ended, come back next time!
    E12: No more deligth tokens remaining! Come back next time!
    E13: No more deligth left! Come back next time!
    E14: not enough sandman provided
    E15: user cannot purchase 0 delight
    E16: failed sending delight
    E18: failed to collect lithium from user
    E19: burning too much delirium, check again please
    E20: can only retrieve excess tokens after delight swap has ended
    E21: cannot change start block if presale has already commenced
    E22: cannot set start block in the past
    E23: cannot change price after start presale
    E24: new delight price is to high!
    E25: new delight price is too low!
    E26: can only send excess delight to dead address after presale has ended
    E27: can only burn unsold presale once!
    E28: start block has to be less than end block

*/


contract DelightVipAccessPresale is Ownable, ReentrancyGuard {

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant FEE_ADDRESS = 0x1DbF98d1e31712De84E79F33fD2e9D70F22A0261;

    address public immutable delightAddress;
    address public immutable sandManAddress;
    
    uint256 public startBlock;
    uint256 public endBlock;

    bool hasBurnedUnsoldPresale;
    
    //SETUP
    uint256 public constant delightVipPresaleSize = 48 * (10 ** 3) * (10 ** 18); // 48,000 delight for l1
    uint256 public delightSaleVipPriceE35 = 48 * (10 ** 33);
    uint256 public delightRemaining = delightVipPresaleSize;
    uint256 public constant oneHourMatic = 1500;
    uint256 public constant minDurationPresale = oneHourMatic * 24 * 3;


    event SandManToDelight(address sender, uint256 sandMantoSwap, uint256 delightPurchaseAmount);
    event BurnUnclaimedDelight(uint256 amountDelightBurned);
    event RetrieveDepreciatedSandManAddresss(address feeAddress, uint256 sandmanInContract);
    event SetStartBlock(uint256 newStartBlock, uint256 newEndBlock);
    event SetSaleVipPrice(uint256 newDeliriumSaleVipPrice);

    constructor(uint256 _startBlock, uint256 _endBlock, address _delightAddress, address _sandManAddress) {
        require(_delightAddress != address(0), "E8");

        startBlock = _startBlock;
        endBlock = _endBlock;
        delightAddress = _delightAddress;
        sandManAddress = _sandManAddress;
    }

    function swapSandManForDelight(uint256 sandManToSwap) external nonReentrant {
        require(msg.sender != FEE_ADDRESS, "E9");
        require(block.number >= startBlock, "E10");
        require(block.number < endBlock, "E11");

        require(delightRemaining > 0, "E12");
        require(IERC20(delightAddress).balanceOf(address(this)) > 0, "E13");
        require(sandManToSwap > 0, "E14");

        uint256 delightPurchaseAmount = (sandManToSwap * delightSaleVipPriceE35) / 1e35;
        
        if (delightRemaining < delightPurchaseAmount)
            delightPurchaseAmount = delightRemaining;

        require(delightPurchaseAmount > 0, "E15");

        assert(delightPurchaseAmount <= delightRemaining);
        assert(delightPurchaseAmount <= IERC20(delightAddress).balanceOf(address(this)));

        delightRemaining = delightRemaining - delightPurchaseAmount;

        require(IERC20(delightAddress).transfer(msg.sender, delightPurchaseAmount), "E16");

        require(IERC20(sandManAddress).transferFrom(msg.sender, FEE_ADDRESS, sandManToSwap), "E18");

        emit SandManToDelight(msg.sender, sandManToSwap, delightPurchaseAmount);

    }

    function setStartBlock(uint256 _newStartBlock, uint256 _newEndBlock) external onlyOwner {
        require(block.number < startBlock, "E21");
        require(block.number < _newStartBlock, "E22");
        require(_newStartBlock < _newEndBlock, "E28");
        require((_newEndBlock - _newStartBlock) > minDurationPresale, "E13");

        startBlock = _newStartBlock;
        endBlock = _newEndBlock;

        emit SetStartBlock(startBlock, endBlock);
    }

    function setSaleVipPrice(uint256 _newDelightSaleVipPriceE35) external onlyOwner {
        require(block.number < startBlock, "E23");
        require(_newDelightSaleVipPriceE35 > 0, "E24");
        
        delightSaleVipPriceE35 = _newDelightSaleVipPriceE35;

        emit SetSaleVipPrice(delightSaleVipPriceE35);
    }

    function sendUnclaimedDelightToDeadAddress() external onlyOwner {
        require(block.number > endBlock, "E26");
        require(!hasBurnedUnsoldPresale, "E27");

        uint256 delightInContract  = IERC20(delightAddress).balanceOf(address(this));

        if (delightInContract > 0)
            require(IERC20(delightAddress).transfer(BURN_ADDRESS, delightInContract), "E16");
        hasBurnedUnsoldPresale = true;

        emit BurnUnclaimedDelight(delightInContract);
    }


}