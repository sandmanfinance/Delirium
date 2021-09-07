/*
   o__ __o        o__ __o__/_   o           __o__   o__ __o        __o__   o         o    o          o  
 <|     v\      <|    v       <|>            |    <|     v\         |    <|>       <|>  <|\        /|> 
 / \     <\     < >           / \           / \   / \     <\       / \   / \       / \  / \\o    o// \ 
 \o/       \o    |            \o/           \o/   \o/     o/       \o/   \o/       \o/  \o/ v\  /v \o/ 
  |         |>   o__/_         |             |     |__  _<|         |     |         |    |   <\/>   |  
 / \       //    |            / \           < >    |       \       < >   < >       < >  / \        / \ 
 \o/      /     <o>           \o/            |    <o>       \o      |     \         /   \o/        \o/ 
  |      o       |             |             o     |         v\     o      o       o     |          |  
 / \  __/>      / \  _\o__/_  / \ _\o__/_  __|>_  / \         <\  __|>_    <\__ __/>    / \        / \ 
                                                                                                       
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DeliriumLockerLiquidity is Ownable {
    using SafeERC20 for IERC20;

    uint256 public immutable UNLOCK_END_BLOCK;

    event Claim(IERC20 deliriumToken, address to);


    /**
     * @notice Constructs the Delirium contract.
     */
    constructor(uint256 blockNumber) {
        UNLOCK_END_BLOCK = blockNumber;
    }

    /**
     * @notice claimSanManLiquidity
     * claimdeliriumToken allows the delirium Team to send delirium Liquidity to the new delirum kingdom.
     * It is only callable once UNLOCK_END_BLOCK has passed.
     * Delirium Liquidity Policy: https://docs.delirium.farm/token-info/delirium-token/liquidity-lock-policy
     */

    function claimSanManLiquidity(IERC20 deliriumLiquidity, address to) external onlyOwner {
        require(block.number > UNLOCK_END_BLOCK, "Delirium is still dreaming...");

        deliriumLiquidity.safeTransfer(to, deliriumLiquidity.balanceOf(address(this)));

        emit Claim(deliriumLiquidity, to);
    }
}