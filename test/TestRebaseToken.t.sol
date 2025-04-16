// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Test} from "../lib/forge-std/src/Test.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestRebaseToken is Test {
    RebaseToken public rebasetoken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() external {
        vm.startPrank(owner);
        rebasetoken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebasetoken)));
        rebasetoken.grantMintAndBurnRole(address(vault));
        (bool success, ) = payable(address(vault)).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function testDepositeLinear(uint _amount) public {
        _amount = bound(_amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, _amount);
        vault.deposite{value: _amount}();
        uint startingbalance = rebasetoken.balanceOf(user);
        console.log("starting Balance ", startingbalance);

        assertEq(startingbalance, _amount);

        vm.warp(block.timestamp + 1 hours);
        uint middle_balance = rebasetoken.balanceOf(user);

        console.log("middle balance ", middle_balance);

        assertGt(middle_balance, startingbalance);

        vm.warp(block.timestamp + 1 hours);

        uint end_balance = rebasetoken.balanceOf(user);

        console.log("end balance ", end_balance);

        assertGt(end_balance, middle_balance);

        assertApproxEqAbs(
            end_balance - middle_balance,
            middle_balance - startingbalance,
            1
        );

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposite{value: amount}();
        assertEq(rebasetoken.balanceOf(user), amount);

        // 2. Redeem
        uint256 startEthBalance = address(user).balance;
        vm.prank(user); // Still acting as user
        vault.redeem(type(uint256).max); // Redeem entire balance

        // 3. Check balances
        assertEq(rebasetoken.balanceOf(user), 0);
        assertEq(address(user).balance, startEthBalance + amount);
    }

    // Helper function to send ETH to the vault
    function addRewardsToVault(uint256 rewardAmount) internal {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}(
            ""
        );
        // For test setup, we might omit the success check, assuming it works.
        // In production tests, asserting success might be desired.
    }

    function testRedeemAfterTimePassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        // Bound inputs
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // Use uint256 for amount
        time = bound(time, 1000, type(uint96).max / 1e18); // Bound time to avoid overflow in interest calc

        // 1. Deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposite{value: depositAmount}();

        // 2. Warp time
        vm.warp(block.timestamp + time);
        uint256 balanceAfterSomeTime = rebasetoken.balanceOf(user);

        // 3. Fund vault with rewards
        uint256 rewardAmount = balanceAfterSomeTime - depositAmount;
        vm.deal(owner, rewardAmount); // Give owner ETH first
        vm.prank(owner);
        addRewardsToVault(rewardAmount); // Owner sends rewards

        // 4. Redeem
        uint256 ethBalanceBeforeRedeem = address(user).balance;
        vm.prank(user);
        vault.redeem(type(uint256).max);

        // 5. Check balances
        assertEq(rebasetoken.balanceOf(user), 0);
        assertEq(
            address(user).balance,
            ethBalanceBeforeRedeem + balanceAfterSomeTime
        );
        assertGt(address(user).balance, ethBalanceBeforeRedeem + depositAmount); // Ensure interest was received
    }

    function testTransfer(uint _amount, uint _amountSend) public {
        _amount = bound(_amount, 2e5, type(uint96).max);
        _amountSend = bound(_amountSend, 0.9e5, _amount - 1e5);

        vm.deal(user, _amount);
        vm.prank(user);
        vault.deposite{value: _amount}();

        address user2 = makeAddr("user2");
        uint userBalance = rebasetoken.balanceOf(user);
        uint user2Balance = rebasetoken.balanceOf(user2);
        assertEq(userBalance, _amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebasetoken.setInterestRate(4e10);

        vm.prank(user);
        rebasetoken.transfer(user2, _amountSend);
        uint userBalanceafterTransfer = rebasetoken.balanceOf(user);
        uint user2BalanceAfterTransfer = rebasetoken.balanceOf(user2);

        assertEq(userBalanceafterTransfer, userBalance - _amountSend);
        assertEq(user2BalanceAfterTransfer, _amountSend);

        assertEq(rebasetoken.getUserInterestrate(user), 5e10);
        assertEq(rebasetoken.getUserInterestrate(user2), 5e10);
    }

    function testOnlyOwnerSetInterestRate(uint _amount) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebasetoken.setInterestRate(_amount);
    }

    function testGetPrincipalBalance(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposite{value: amount}();

        // 2. Check principal balance
        // Assuming function is named principleBalanceOf or similar
        assertEq(rebasetoken.getPrincipalBalnceOf(user), amount);

        // 3. Warp time
        vm.warp(block.timestamp + 1 hours);

        // 4. Check principal balance again - should be unchanged
        assertEq(rebasetoken.getPrincipalBalnceOf(user), amount);
    }

    function testgetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTOkenAddress(), address(rebasetoken));
    }
}
