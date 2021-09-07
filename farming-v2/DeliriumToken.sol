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

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// DeliriumToken
contract DeliriumToken is ERC20, Ownable {

    constructor() 
        ERC20('DELIRIUM', 'DELIRIUM')
    {}

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}