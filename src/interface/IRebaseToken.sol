// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

interface IRebaseToken {
    function mint(address _to, uint _amount) external;

    function burn(address _from, uint _amount) external;

    function balanceOf(address _user) external returns (uint);
}
