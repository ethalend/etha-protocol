//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Helpers.sol";
import "../libs/UniversalERC20.sol";
import "../interfaces/IBalancerVault.sol";
import "hardhat/console.sol";

contract BalancerResolver is Helpers {
	using SafeMath for uint256;
	using UniversalERC20 for IERC20;

	IBalancerVault public constant balancerVault =
		IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

	// EVENTS
	event LogSwap(address indexed src, address indexed dest, uint256 amount);

	/**
	 * @dev Swap tokens in Quickswap dex
	 * @param fromToken asset to swap from
	 * @param destToken asset to swap to
	 * @param tokenAmt amount of fromTokens to swap
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of tokens swapped in memory contract
	 */
	function swap(
		bytes32 poolId,
		address fromToken,
		address destToken,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId).div(divider) : tokenAmt;

		require(realAmt > 0, "ZERO AMOUNT");
		require(address(fromToken) != address(destToken), "SAME ASSETS");

		// Approve fromToken to Vault
		IERC20(fromToken).universalApprove(address(balancerVault), realAmt);

		SingleSwap memory _singleSwap;
		_singleSwap.poolId = poolId;
		_singleSwap.kind = SwapKind.GIVEN_IN;
		_singleSwap.assetIn = fromToken;
		_singleSwap.assetOut = destToken;
		_singleSwap.amount = realAmt;
		_singleSwap.userData = "0x";

		FundManagement memory _fundManagement;
		_fundManagement.sender = address(this);
		_fundManagement.fromInternalBalance = false;
		_fundManagement.recipient = payable(address(this));
		_fundManagement.toInternalBalance = false;

		uint256 received = balancerVault.swap(
			_singleSwap,
			_fundManagement,
			1,
			block.timestamp + 1
		);

		// set destTokens received
		if (setId > 0) {
			setUint(setId, received);
		}

		emit LogSwap(fromToken, destToken, realAmt);
	}
}

contract BalancerLogic is BalancerResolver {
	receive() external payable {}
}
