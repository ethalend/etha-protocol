//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/UniversalERC20.sol";
import "../interfaces/ICurvePool.sol";
import "./Helpers.sol";

contract CurveLogic is Helpers {
	using UniversalERC20 for IERC20;
	using SafeMath for uint256;

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

	function toInt128(uint256 num) internal pure returns (int128) {
		return int128(int256(num));
	}

	/**
	 * @notice add liquidity to Curve Pool
	 * @param getId read value from memory contract
	 * @param setId set dest tokens received to memory contract
	 */
	function swap(
		ICurvePool pool,
		address src,
		address dest,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : tokenAmt;

		uint256 i;
		uint256 j;

		for (uint256 x = 1; x <= 3; x++) {
			if (pool.underlying_coins(x - 1) == src) i = x;
			if (pool.underlying_coins(x - 1) == dest) j = x;
		}

		require(i != 0 && j != 0);

		IERC20(src).universalApprove(address(pool), realAmt);

		uint256 received = pool.exchange_underlying(
			toInt128(i - 1),
			toInt128(j - 1),
			realAmt,
			0
		);

		// set j tokens received
		if (setId > 0) {
			setUint(setId, received);
		}

		emit LogSwap(
			pool.underlying_coins(i - 1),
			pool.underlying_coins(j - 1),
			realAmt
		);
	}

	/**
	 * @notice add liquidity to Curve Pool
	 * @param tokenId id of the token to remove liq. Should be 0, 1 or 2
	 * @param getId read value from memory contract
	 * @param setId set LP tokens received to memory contract
	 */
	function addLiquidity(
		ICurvePool pool,
		uint256 tokenAmt,
		uint256 tokenId, // 0, 1 or 2
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		IERC20 token;

		try pool.underlying_coins(tokenId) returns (address _token) {
			token = IERC20(_token);
		} catch {
			revert("!TOKENID");
		}

		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : tokenAmt;

		uint256[3] memory tokenAmts;
		tokenAmts[tokenId] = realAmt;

		IERC20(token).universalApprove(address(pool), realAmt);

		uint256 liquidity = pool.add_liquidity(tokenAmts, 0, true);

		// set LP tokens received
		if (setId > 0) {
			setUint(setId, liquidity);
		}

		emit LogLiquidityAdd(address(token), address(0), realAmt, 0);
	}

	/**
	 * @notice remove liquidity from Curve Pool
	 * @param tokenAmt amount of pool Tokens to burn
	 * @param tokenId id of the token to remove liq. Should be 0, 1 or 2
	 * @param getId read value of amount from memory contract
	 * @param setId set value of tokens received in memory contract
	 */
	function removeLiquidity(
		ICurvePool pool,
		uint256 tokenAmt,
		uint256 tokenId,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : tokenAmt;

		require(realAmt > 0, "ZERO AMOUNT");
		require(tokenId <= 2, "INVALID TOKEN");

		IERC20 poolToken = IERC20(pool.lp_token());

		poolToken.universalApprove(address(pool), realAmt);

		uint256 amountReceived = pool.remove_liquidity_one_coin(
			realAmt,
			int128(int256(tokenId)),
			1,
			true
		);

		// set tokens received
		if (setId > 0) {
			setUint(setId, amountReceived);
		}

		emit LogLiquidityRemove(
			pool.underlying_coins(tokenId),
			address(0),
			amountReceived,
			0
		);
	}
}
