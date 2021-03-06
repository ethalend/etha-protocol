//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libs/UniversalERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IDistribution.sol";
import "hardhat/console.sol";
import "./Helpers.sol";

contract DSMath is Helpers {
	function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
		require((z = x + y) >= x, "math-not-safe");
	}

	function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
		require((z = x - y) <= x, "math-not-safe");
	}

	function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
		require(y == 0 || (z = x * y) / y == x, "math-not-safe");
	}

	function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
		require(_b > 0); // Solidity only automatically asserts when dividing by 0
		uint256 c = _a / _b;
		// assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
		return c;
	}

	uint256 constant WAD = 10**18;

	function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
		z = add(mul(x, y), WAD / 2) / WAD;
	}

	function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
		z = add(mul(x, WAD), y / 2) / y;
	}
}

contract VaultResolver is DSMath {
	using UniversalERC20 for IERC20;
	using SafeMath for uint256;

	event VaultDeposit(address indexed erc20, uint256 tokenAmt);
	event VaultWithdraw(address indexed erc20, uint256 tokenAmt);
	event VaultClaim(address indexed erc20, uint256 tokenAmt);
	event Claim(address indexed erc20, uint256 tokenAmt);

	function _payFees(
		address _vault,
		address underlying,
		uint256 amt
	) internal returns (uint256 feesPaid) {
		(uint256 fee, uint256 maxFee, address feeRecipient) = getVaultFee(
			_vault
		);

		if (fee > 0) {
			require(feeRecipient != address(0), "ZERO ADDRESS");

			feesPaid = div(mul(amt, fee), maxFee);

			IERC20(underlying).universalTransfer(feeRecipient, feesPaid);
		}
	}

	/**
	 * @dev Deposit tokens to ETHA Vault
	 * @param vault address of vault
	 * @param tokenAmt amount of tokens to deposit
	 * @param getId read value of tokenAmt from memory contract
	 */
	function deposit(
		IVault vault,
		uint256 tokenAmt,
		uint256 getId
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId) : tokenAmt;

		require(realAmt > 0, "!AMOUNT");

		IERC20 erc20 = IERC20(address(vault.underlying()));
		erc20.universalApprove(address(vault), realAmt);

		vault.deposit(realAmt);
		emit VaultDeposit(address(erc20), realAmt);
	}

	/**
	 * @dev Withdraw tokens from ETHA Vault
	 * @param vault address of vault
	 * @param tokenAmt amount of vault tokens to withdraw
	 * @param getId read value of tokenAmt from memory contract
	 */
	function withdraw(
		IVault vault,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId) : tokenAmt;

		require(vault.balanceOf(address(this)) >= realAmt, "!BALANCE");

		address distToken = IDistribution(vault.distribution()).rewardsToken();
		uint256 initialBal = IERC20(distToken).balanceOf(address(this));

		vault.withdraw(realAmt);
		address underlying = address(vault.underlying());
		emit VaultWithdraw(underlying, realAmt);

		uint256 feesPaid = _payFees(address(vault), underlying, realAmt);

		uint256 _claimed = IERC20(distToken).balanceOf(address(this)).sub(
			initialBal
		);

		// set tokens received after paying fees
		if (setId > 0) {
			setUint(setId, realAmt.sub(feesPaid));
		}

		if (_claimed > 0) {
			emit Claim(distToken, _claimed);
		}
	}

	/**
	 * @dev claim rewards from ETHA Vault
	 * @param vault address of vault
	 * @param setId store value of rewards received to memory contract
	 */
	function claim(IVault vault, uint256 setId) external {
		address distToken = IDistribution(vault.distribution()).rewardsToken();
		uint256 initialBal = IERC20(distToken).balanceOf(address(this));

		uint256 claimed = vault.claim();

		// set rewards received
		if (setId > 0) {
			setUint(setId, claimed);
		}

		if (claimed > 0) {
			emit VaultClaim(address(vault.target()), claimed);
		}

		uint256 _claimed = IERC20(distToken).balanceOf(address(this)).sub(
			initialBal
		);

		if (_claimed > 0) {
			emit Claim(distToken, _claimed);
		}
	}
}

contract VaultLogic is VaultResolver {
	receive() external payable {}
}
