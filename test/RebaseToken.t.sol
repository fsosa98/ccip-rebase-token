// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(address(rebaseToken));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        vm.deal(owner, rewardAmount);
        vm.prank(owner);
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
        if (!success) revert();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        vm.stopPrank();

        uint256 balance1 = rebaseToken.balanceOf(user);

        vm.warp(block.timestamp + 1 hours);
        uint256 balance2 = rebaseToken.balanceOf(user);

        vm.warp(block.timestamp + 1 hours);
        uint256 balance3 = rebaseToken.balanceOf(user);

        assertApproxEqAbs(balance2 - balance1, balance3 - balance2, 1);
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        vm.deal(user, amount);
        vm.startPrank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);

        vault.redeem(amount);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(user.balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint32).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        vm.warp(block.timestamp + time);
        uint256 balance = rebaseToken.balanceOf(user);
        addRewardsToVault(balance - depositAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = user.balance;
        assertEq(ethBalance, balance);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 userBalance2 = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(userBalance2, 0);

        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        assertEq(rebaseToken.balanceOf(user), userBalance - amountToSend);
        assertEq(rebaseToken.balanceOf(user2), userBalance2 + amountToSend);
        assertEq(rebaseToken.getUserInterestRate(user), rebaseToken.getUserInterestRate(user2));
    }

    function testUserCannotSetInterestRate(uint256 interestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(interestRate);
    }

    function testUserCannotCallMintAndBurn() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 10, rebaseToken.getInterestRate());
        vm.expectRevert();
        rebaseToken.burn(user, 10);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecrease(uint256 interestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        interestRate = bound(interestRate, initialInterestRate, type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(interestRate);
        assertEq(rebaseToken.getInterestRate(), initialInterestRate);
    }
}
