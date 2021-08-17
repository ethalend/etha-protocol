//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStrat.sol";
import "../interfaces/IVault.sol";
import {ISavingsContractV2, IBoostedDualVaultWithLockup} from "../interfaces/IMStable.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../utils/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract MStableStrat is IStrat {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	// ==== STATE ===== //

	IVault public vault;

	IERC20 public constant WMATIC =
		IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

	IERC20 public constant MTA =
		IERC20(0xF501dd45a1198C2E1b5aEF5314A68B9006D842E0);

	IUniswapV2Router constant ROUTER =
		IUniswapV2Router(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

	// mStable Save contract
	ISavingsContractV2 public savings =
		ISavingsContractV2(0x5290Ad3d83476CA6A2b178Cd9727eE1EF72432af);

	// mStable Boosted Vault
	IBoostedDualVaultWithLockup public boostedVault =
		IBoostedDualVaultWithLockup(0x32aBa856Dc5fFd5A56Bcd182b13380e5C855aa29);

	// deposit token (mUSD)
	IERC20 public underlying;

	Timelock public timelock;

	// ==== MODIFIERS ===== //

	modifier onlyVault() {
		require(msg.sender == address(vault));
		_;
	}

	// ==== INITIALIZATION ===== //

	constructor(IVault vault_, IERC20 _underlying) {
		vault = vault_;
		underlying = _underlying;

		timelock = new Timelock(msg.sender, 7 days);

		// Approve vault for withdrawals and claims
		underlying.safeApprove(address(vault), type(uint256).max);
		WMATIC.safeApprove(address(vault), type(uint256).max);
		MTA.safeApprove(address(vault), type(uint256).max);
		MTA.safeApprove(address(ROUTER), type(uint256).max);

		// Approve for investing musd and imusd
		underlying.safeApprove(address(savings), type(uint256).max);
		IERC20(address(savings)).safeApprove(
			address(boostedVault),
			type(uint256).max
		);
	}

	// ==== GETTERS ===== //

	/**
		@dev total value of mUSD tokens staked on Mstable's contracts
	*/
	function calcTotalValue() external view override returns (uint256) {
		uint256 credits = boostedVault.balanceOf(address(this));
		return savings.creditsToUnderlying(credits);
	}

	/**
		@dev amount of claimable MATIC
	*/
	function totalYield() external view override returns (uint256) {
		(uint256 mtaEarned, uint256 maticEarned) = boostedVault.earned(
			address(this)
		);

		address[] memory path = new address[](2);
		path[0] = address(MTA);
		path[1] = address(WMATIC);

		uint256 toReceive = ROUTER.getAmountsOut(mtaEarned, path)[
			path.length - 1
		];

		return maticEarned.add(toReceive);
	}

	// ==== MAIN FUNCTIONS ===== //

	/**
		@notice Invest LP Tokens into mStable staking contract
		@dev can only be called by the vault contract
		@dev credits = balance
	*/
	function invest() external override onlyVault {
		uint256 balance = underlying.balanceOf(address(this));
		require(balance > 0);

		console.log("underlying bal", balance);

		uint256 credits = savings.depositSavings(balance, address(this));
		console.log("credits bal", credits);

		boostedVault.stake(address(this), credits);
		console.log("vault bal", boostedVault.balanceOf(address(this)));
	}

	/**
		@notice Redeem LP Tokens from mStable staking contract
		@dev can only be called by the vault contract
		@param amount amount of LP Tokens to withdraw
	*/
	function divest(uint256 amount) public override onlyVault {
		uint256 credits = savings.underlyingToCredits(amount);
		console.log("credits bal", credits);
		boostedVault.withdraw(credits);

		uint256 received = savings.balanceOf(address(this));
		console.log("received bal", received);

		uint256 massetReturned = savings.redeemCredits(received);
		console.log("masset bal", massetReturned);

		underlying.safeTransfer(address(vault), massetReturned);
	}

	/**
		@notice Redeem underlying assets from curve Aave pool and Matic rewards from gauge
		@dev can only be called by the vault contract
		@dev only used when harvesting
	*/
	function claim() external override onlyVault returns (uint256 claimed) {
		boostedVault.claimReward();

		uint256 claimedMTA = MTA.balanceOf(address(this));

		// If received MTA, swap to WMATIC
		if (claimedMTA > 0) {
			address[] memory path = new address[](2);
			path[0] = address(MTA);
			path[1] = address(WMATIC);

			ROUTER.swapExactTokensForTokens(
				claimedMTA,
				1,
				path,
				address(this),
				block.timestamp + 1
			)[path.length - 1];
		}

		claimed = WMATIC.balanceOf(address(this));
		WMATIC.safeTransfer(address(vault), claimed);
	}

	// ==== RESCUE ===== //

	// IMPORTANT: This function can only be called by the timelock to recover any token amount including deposited cTokens
	// However, the owner of the timelock must first submit their request and wait 7 days before confirming.
	// This gives depositors a good window to withdraw before a potentially malicious escape
	// The intent is for the owner to be able to rescue funds in the case they become stuck after launch
	// However, users should not trust the owner and watch the timelock contract least once a week on Etherscan
	// In the future, the timelock contract will be destroyed and the functionality will be removed after the code gets audited
	function rescue(
		address _token,
		address _to,
		uint256 _amount
	) external {
		require(msg.sender == address(timelock));
		IERC20(_token).transfer(_to, _amount);
	}

	// Any tokens (other than the lpToken) that are sent here by mistake are recoverable by the vault owner
	function sweep(address _token) external {
		address owner = vault.owner();
		require(msg.sender == owner);
		require(_token != address(underlying));
		IERC20(_token).transfer(owner, IERC20(_token).balanceOf(address(this)));
	}
}
