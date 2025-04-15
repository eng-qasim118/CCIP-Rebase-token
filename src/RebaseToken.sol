// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyIncrease(
        uint256 currentInterestRate,
        uint256 proposedInterestRate
    );

    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping(address => uint) private s_userInterestRate;
    mapping(address => uint) private s_lastUpdatedTimestap;
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Wealthiee", "WLEE") {}

    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyIncrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    function balanceOf(address _user) public view override returns (uint) {
        //returns total balance with interest add
        return
            (super.balanceOf(_user) *
                _calculateAccomulatedInterestOfUserSinceLateUpdate(_user)) /
            PRECISION_FACTOR;
    }

    function transfer(
        address _recipient,
        uint _amount
    ) public override returns (bool) {
        _mintAccuredInterestRate(msg.sender);
        _mintAccuredInterestRate(_recipient);
        if (_amount == type(uint).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint _amount
    ) public override returns (bool) {
        _mintAccuredInterestRate(recipient);
        if (_amount == type(uint).max) {
            _amount = balanceOf(sender);
        }
        if (balanceOf(recipient) == 0) {
            s_userInterestRate[recipient] = s_userInterestRate[sender];
        }
        return super.transferFrom(sender, recipient, _amount);
    }

    function _calculateAccomulatedInterestOfUserSinceLateUpdate(
        address _user
    ) internal view returns (uint) {
        //principal ammount + (principal amount * interest rate * timestamp)
        //principal amount (1+(interestrate * timestamp))
        uint timePassed = block.timestamp - s_lastUpdatedTimestap[_user];
        uint interestrate = (PRECISION_FACTOR +
            (s_userInterestRate[_user] * timePassed));
        return interestrate;
    }

    function mint(address _to, uint _amount) external {
        _mintAccuredInterestRate(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint _amount) external {
        if (_amount == type(uint).max) {
            _amount = balanceOf(_from);
        }
        _mintAccuredInterestRate(_from);
        _burn(_from, _amount);
    }

    function _mintAccuredInterestRate(address _user) internal {
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        // set the users last updated timestamp (Effect)
        s_lastUpdatedTimestap[_user] = block.timestamp;
        // mint the user the balance increase (Interaction)
        _mint(_user, balanceIncrease);
    }

    ////////////
    //Getters//
    //////////

    function getContractInterestRate() external view returns (uint) {
        return s_interestRate;
    }

    function getUserInterestrate(address _user) external view returns (uint) {
        return s_userInterestRate[_user];
    }

    function getPrincipalBalnceOf(address _user) external view returns (uint) {
        return super.balanceOf(_user);
    }
}
