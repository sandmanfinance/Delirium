// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IStrategySandMan {
    function depositReward(uint256 _depositAmt) external returns (bool);
}