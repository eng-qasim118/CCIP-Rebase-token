// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;
import {IRebaseToken} from "./interface/IRebaseToken.sol";

contract Vault {
    // State variable to store the RebaseToken contract address
    IRebaseToken private immutable i_rebaseToken;

    event Deposite(address indexed depositor, uint amount);
    event Redeemed(address indexed receiver, uint _amount);

    error Vault__RedeemFailed();

    // Constructor to set the immutable token address
    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    function deposite() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposite(msg.sender, msg.value);
    }

    function redeem(uint _amount) external {
        if (_amount == type(uint).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeemed(msg.sender, _amount);
    }

    function getRebaseTOkenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
