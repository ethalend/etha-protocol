//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IMAsset.sol";
import "./Helpers.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MStableResolver is Helpers {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;

	IMasset internal constant musd =
		IMasset(0xE840B73E5287865EEc17d250bFb1536704B43B21);

	// EVENTS
	event LogSwap(address indexed src, address indexed dest, uint256 amount);
	event LogLiquidityAdd(
		address indexed tokenA,
		address indexed tokenB,
		uint256 amountA,
		uint256 amountB
	);
	event LogLiquidityRemove(
		address indexed tokenA,
		address indexed tokenB,
		uint256 amountA,
		uint256 amountB
	);

	/**
	 * @dev Swap tokens in Quickswap dex
	 * @param fromToken asset to swap from
	 * @param destToken asset to swap to
	 * @param tokenAmt amount of fromTokens to swap
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of tokens swapped in memory contract
	 */
	function swap(
		IERC20 fromToken,
		IERC20 destToken,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : tokenAmt;
		require(realAmt > 0, "ZERO AMOUNT");
		require(address(fromToken) != address(destToken), "SAME ASSETS");

		// Approve mUSD
		IERC20(fromToken).safeApprove(address(musd), 0);
		IERC20(fromToken).safeApprove(address(musd), realAmt);

		uint256 received = musd.swap(
			address(fromToken),
			address(destToken),
			realAmt,
			1,
			address(this)
		);

		// set destTokens received
		if (setId > 0) {
			setUint(setId, received);
		}

		emit LogSwap(address(fromToken), address(destToken), realAmt);
	}

	/**
	 * @dev Add liquidity to mUSD pool
	 * @param amt amount of base tokens to add
	 * @param getId read value of tokenAmt from memory contract position 1
	 * @param setId set value of mUSD received in memory contract
	 */
	function addLiquidity(
		IERC20 token,
		uint256 amt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : amt;

		require(realAmt > 0, "INVALID AMOUNT");

		// Approve mUSD
		IERC20(token).safeApprove(address(musd), 0);
		IERC20(token).safeApprove(address(musd), realAmt);

		// Mint mUSD
		uint256 massetsMinted = musd.mint(
			address(token),
			realAmt,
			1,
			address(this)
		);

		// set mUSD received
		if (setId > 0) {
			setUint(setId, massetsMinted);
		}

		emit LogLiquidityAdd(address(token), address(0), realAmt, 0);
	}

	/**
	 * @dev Remove liquidity from mUSD pool
	 * @param amt amount of msud to redeem
	 * @param getId read value of tokenAmt from memory contract position 1
	 * @param setId set value of mUSD received in memory contract
	 */
	function removeLiquidity(
		IERC20 token,
		uint256 amt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : amt;

		require(realAmt > 0, "INVALID AMOUNT");

		// Burn mUSD to get base asset
		uint256 received = musd.redeem(
			address(token),
			realAmt,
			1,
			address(this)
		);

		// set amount of base assets received
		if (setId > 0) {
			setUint(setId, received);
		}

		emit LogLiquidityRemove(address(token), address(0), received, 0);
	}
}

contract MStableLogic is MStableResolver {
	receive() external payable {}
}
