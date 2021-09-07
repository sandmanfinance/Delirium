// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20{
  uint8 updateDecimals;
  constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) ERC20(_name, _symbol) public {
    _mint(msg.sender, _initialSupply);
    updateDecimals = _decimals;
  }

  function decimals() public view virtual override returns (uint8) {
    return updateDecimals;
  }
}
