// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
interface IERC20 {
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    
}