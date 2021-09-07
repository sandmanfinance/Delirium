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

/*
    ERROR REF
    ---------
    E1: Delight cannot be equal to delirium
    E2: delight is not insane yet.
    E3: Not Enough tokens in contract for swap
    E4: failed sending delight
    E5: can only send excess delight to dead address after presale has ended
    E6: can only burn unsold presale once!
    E7: burning too much delirium, check again please
    E8: cannot change start block if presale has already commenced
    E9: cannot set start block in the past
*/
import "./DelightToken.sol";

contract DelightMadness is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Burn address
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;


    // Tokens
    DelightToken public immutable  delightToken;
    
    IERC20 public immutable deliriumToken;

    bool hasBurnedUnsoldPresale;

    uint256 public startBlock;

    event DelightToDelirium(address sender, uint256 amount);
    event burnUnclaimedDelight(uint256 amount);
    event startBlockChanged(uint256 newStartBlock);

    constructor(uint256 _startBlock, address _delightAddress, address _deliriumAddress) {
        require(_delightAddress != _deliriumAddress, "E1");
        
        startBlock = _startBlock;
        delightToken = DelightToken(_delightAddress);
        deliriumToken = IERC20(_deliriumAddress);
    }

    function swapDelightForDelirium() external nonReentrant {
        require(block.number >= startBlock, "E2");

        uint256 swapAmount = delightToken.balanceOf(msg.sender);
        
        require(deliriumToken.balanceOf(address(this)) >= swapAmount, "E3");
        require(delightToken.transferFrom(msg.sender, BURN_ADDRESS, swapAmount), "E4");
        
        deliriumToken.safeTransfer(msg.sender, swapAmount);

        emit DelightToDelirium(msg.sender, swapAmount);
    }

    function sendUnclaimedDeliriumToDeadAddress() external onlyOwner {
        require(block.number > delightToken.endBlock(), "E5");
        require(!hasBurnedUnsoldPresale, "E6");
        require(delightToken.delightRemaining() <= deliriumToken.balanceOf(address(this)), "E7");

        if (delightToken.delightRemaining() > 0)
            deliriumToken.safeTransfer(BURN_ADDRESS, delightToken.delightRemaining());
        hasBurnedUnsoldPresale = true;

        emit burnUnclaimedDelight(delightToken.delightRemaining());
    }

    function setStartBlock(uint256 _newStartBlock) external onlyOwner {
        require(block.number < startBlock, "E8");
        require(block.number < _newStartBlock, "E9");
        startBlock = _newStartBlock;

        emit startBlockChanged(_newStartBlock);
    }

}