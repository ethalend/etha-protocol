//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStrat.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ICurveGauge.sol";
import "../interfaces/IUniswapV2Router.sol";
import "../utils/Timelock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CurveStrat is IStrat {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	// ==== STATE ===== //

	IVault public vault;

	IERC20 public constant WMATIC =
		IERC20(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

	IERC20 public constant CRV =
		IERC20(0x172370d5Cd63279eFa6d502DAB29171933a610AF);

	ICurveGauge public gauge =
		ICurveGauge(0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c);

	IUniswapV2Router constant ROUTER =
		IUniswapV2Router(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

	IERC20 public underlying;

	Timelock public timelock;

	// ==== MODIFIERS ===== //

	modifier onlyVault {
		require(msg.sender == address(vault));
		_;
	}

	// ==== INITIALIZATION ===== //

	constructor(IVault vault_) {
		vault = vault_;
		underlying = IERC20(gauge.lp_token());
		timelock = new Timelock(msg.sender, 7 days);

		// Infite Approvals
		underlying.safeApprove(address(gauge), type(uint256).max);
		underlying.safeApprove(address(vault), type(uint256).max);
		CRV.safeApprove(address(ROUTER), type(uint256).max);
		WMATIC.safeApprove(address(vault), type(uint256).max);
	}

	// ==== GETTERS ===== //

	/**
		@dev total value of LP tokens staked on Curve's Gauge
	*/
	function calcTotalValue() external view override returns (uint256) {
		return gauge.balanceOf(address(this));
	}

	/**
		@dev amount of claimable WMATIC
	*/
	function totalYield() external override returns (uint256) {
		return gauge.claimable_reward(address(this), address(WMATIC));
	}

	/**
		@dev amount of claimable CRV
	*/
	function totalYield2() external returns (uint256) {
		return gauge.claimable_reward(address(this), address(CRV));
	}

	// ==== MAIN FUNCTIONS ===== //

	/**
		@notice Invest LP Tokens into Curve's Gauge
		@dev can only be called by the vault contract
	*/
	function invest() external override onlyVault {
		uint256 balance = underlying.balanceOf(address(this));
		require(balance > 0);

		gauge.deposit(balance);
	}

	/**
		@notice Redeem underlying assets from curve Aave pool
		@dev can only be called by the vault contract
		@dev wont always return the exact desired amount
		@param amount amount of underlying asset to withdraw
	*/
	function divest(uint256 amount) public override onlyVault {
		gauge.withdraw(amount);

		underlying.safeTransfer(address(vault), amount);
	}

	/**
		@notice Redeem underlying assets from curve Aave pool and Matic rewards from gauge
		@dev can only be called by the vault contract
		@dev only used when harvesting
	*/
	function claim() external override onlyVault returns (uint256 claimed) {
		gauge.claim_rewards();

		uint256 claimedCurve = CRV.balanceOf(address(this));

		// If received CRV, swap to WMATIC
		if (claimedCurve > 0) {
			address[] memory path = new address[](2);
			path[0] = address(CRV);
			path[1] = address(WMATIC);

			ROUTER.swapExactTokensForTokens(
				claimedCurve,
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
