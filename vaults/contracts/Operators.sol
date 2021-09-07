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

pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Operators is Ownable {
    mapping(address => bool) public operators;

    event OperatorUpdated(address indexed operator, bool indexed status);

    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    // Update the status of the operator
    function updateOperator(address _operator, bool _status) external onlyOwner {
        operators[_operator] = _status;
        emit OperatorUpdated(_operator, _status);
    }
}
