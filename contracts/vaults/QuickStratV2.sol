//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStrat.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IStakingRewards.sol";
import "../interfaces/IDragonLair.sol";
import "../utils/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract QuickStratV2 is IStrat {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	// ==== STATE ===== //

	IVault public vault;

	IERC20 public constant QUICK =
		IERC20(0x831753DD7087CaC61aB5644b308642cc1c33Dc13);

	IDragonLair public constant DQUICK =
		IDragonLair(0xf28164A485B0B2C90639E47b0f377b4a438a16B1);

	// Quikswap LP Staking Rewards Contract
	IStakingRewards public staking;

	// Quickswap LP
	IERC20 public underlying;

	Timelock public timelock;

	// ==== MODIFIERS ===== //

	modifier onlyVault() {
		require(msg.sender == address(vault));
		_;
	}

	// ==== INITIALIZATION ===== //

	constructor(
		IVault vault_,
		IStakingRewards _staking,
		IERC20 _underlying
	) {
		vault = vault_;
		staking = _staking;
		underlying = _underlying;

		timelock = new Timelock(msg.sender, 7 days);

		// Infite Approvals
		underlying.safeApprove(address(staking), type(uint256).max);
		underlying.safeApprove(address(vault), type(uint256).max);
		QUICK.safeApprove(address(vault), type(uint256).max);
	}

	// ==== GETTERS ===== //

	/**
		@dev total value of LP tokens staked on Curve's Gauge
	*/
	function calcTotalValue() external view override returns (uint256) {
		return staking.balanceOf(address(this));
	}

	/**
		@dev amount of claimable QUICK
	*/
	function totalYield() external view override returns (uint256) {
		return staking.earned(address(this));
	}

	// ==== MAIN FUNCTIONS ===== //

	/**
		@notice Invest LP Tokens into Quickswap staking contract
		@dev can only be called by the vault contract
	*/
	function invest() external override onlyVault {
		uint256 balance = underlying.balanceOf(address(this));
		require(balance > 0);

		staking.stake(balance);
	}

	/**
		@notice Redeem LP Tokens from Quickswap staking contract
		@dev can only be called by the vault contract
		@param amount amount of LP Tokens to withdraw
	*/
	function divest(uint256 amount) public override onlyVault {
		staking.withdraw(amount);

		underlying.safeTransfer(address(vault), amount);
	}

	/**
		@notice Claim QUICK rewards from staking contract
		@dev can only be called by the vault contract
		@dev only used when harvesting
	*/
	function claim() external override onlyVault returns (uint256 claimed) {
		staking.getReward();

		uint256 claimedDQUICK = DQUICK.balanceOf(address(this));
		DQUICK.leave(claimedDQUICK);

		claimed = QUICK.balanceOf(address(this));
		QUICK.safeTransfer(address(vault), claimed);
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
