//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/ICERC20.sol";
import "../interfaces/ICETH.sol";
import "../interfaces/IComptroller.sol";
import "../interfaces/IWallet.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IProtocolDistribution.sol";
import "../interfaces/IAToken.sol";
import "../libs/UniversalERC20.sol";
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

contract CreamHelpers is DSMath {
	using UniversalERC20 for IERC20;

	/**
	 * @dev get ethereum address for trade
	 */
	function getAddressETH() public pure returns (address eth) {
		eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	}

	/**
	 * @dev get Compound Comptroller Address
	 */
	function getComptrollerAddress() public pure returns (address troller) {
		troller = 0x20CA53E2395FA571798623F1cFBD11Fe2C114c24;
	}

	/**
	 * @dev Transfer ETH/ERC20 to user
	 */

	function enterMarket(address cErc20) internal {
		IComptroller troller = IComptroller(getComptrollerAddress());
		address[] memory markets = troller.getAssetsIn(address(this));
		bool isEntered = false;
		for (uint256 i = 0; i < markets.length; i++) {
			if (markets[i] == cErc20) {
				isEntered = true;
			}
		}
		if (!isEntered) {
			address[] memory toEnter = new address[](1);
			toEnter[0] = cErc20;
			troller.enterMarkets(toEnter);
		}
	}

	function _sync(address erc20) internal {
		address distribution = IRegistry(IWallet(address(this)).registry())
			.distributionContract(erc20);

		// If distribution contract exists
		if (distribution != address(0)) {
			uint256 suppliedBalanceCream = wmul(
				ICToken(getCrToken(erc20)).balanceOf(address(this)),
				ICToken(getCrToken(erc20)).exchangeRateCurrent()
			);
			uint256 suppliedBalanceAave = IAToken(getAToken(erc20)).balanceOf(
				address(this)
			);

			// total supplied for given token in 2 protocols
			uint256 totalSupplied = add(
				suppliedBalanceCream,
				suppliedBalanceAave
			);

			// current staked amount
			uint256 totalStaked = IProtocolDistribution(distribution).balanceOf(
				address(this)
			);

			// if total staked is bigger, unstake
			if (totalStaked > totalSupplied) {
				IProtocolDistribution(distribution).withdraw(
					sub(totalStaked, totalSupplied)
				);
			}

			// if total supplied is bigger, stake
			if (totalSupplied > totalStaked) {
				IProtocolDistribution(distribution).stake(
					sub(totalSupplied, totalStaked)
				);
			}
		}
	}

	function _payFees(address erc20, uint256 amt)
		internal
		returns (uint256 feesPaid)
	{
		(uint256 fee, uint256 maxFee, address feeRecipient) = getLendingFee(
			erc20
		);

		if (fee > 0) {
			require(feeRecipient != address(0), "ZERO ADDRESS");

			feesPaid = div(mul(amt, fee), maxFee);

			IERC20(erc20).universalTransfer(
				feeRecipient,
				div(mul(amt, fee), maxFee)
			);
		}
	}
}

contract CreamResolver is CreamHelpers {
	using SafeMath for uint256;
	using UniversalERC20 for IERC20;

	event LogMint(address indexed erc20, uint256 tokenAmt);
	event LogRedeem(address indexed erc20, uint256 tokenAmt);
	event LogBorrow(address indexed erc20, uint256 tokenAmt);
	event LogPayback(address indexed erc20, uint256 tokenAmt);

	/**
	 * @dev Deposit ETH/ERC20 and mint Cream Tokens
	 */
	function mintCToken(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		address crToken = getCrToken(erc20);
		enterMarket(crToken);

		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;
		uint256 toDeposit = realAmt;

		if (erc20 == getAddressETH()) {
			ICETH cToken = ICETH(crToken);
			cToken.mintNative{value: realAmt}();
		} else {
			require(
				erc20 == ICERC20(crToken).underlying(),
				"INVALID-UNDERLYING"
			);

			IERC20 token = IERC20(erc20);
			uint256 balance = token.balanceOf(address(this));
			if (toDeposit > balance) {
				toDeposit = balance;
			}
			ICERC20 cToken = ICERC20(crToken);
			IERC20(erc20).universalApprove(crToken, toDeposit);
			assert(cToken.mint(toDeposit) == 0); // no error message on assert
		}

		_sync(erc20);

		// set crTokens received
		if (setId > 0) setUint(setId, realAmt);

		emit LogMint(erc20, toDeposit);
	}

	function redeemCToken(
		address erc20,
		uint256 cTokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : cTokenAmt;

		ICToken cToken = ICToken(getCrToken(erc20));
		uint256 toBurn = cToken.balanceOf(address(this));
		if (toBurn > realAmt) {
			toBurn = realAmt;
		}
		require(cToken.redeem(toBurn) == 0, "something went wrong");
		uint256 tokenReturned = wmul(toBurn, cToken.exchangeRateCurrent());

		_sync(erc20);

		uint256 feesPaid = _payFees(erc20, tokenReturned);

		// set amount of tokens redeemed minus fees
		if (setId > 0) {
			setUint(setId, tokenReturned.sub(feesPaid));
		}

		emit LogRedeem(erc20, tokenReturned);
	}

	/**
	 * @dev Redeem ETH/ERC20 and mint Cream Tokens
	 * @param tokenAmt Amount of token To Redeem
	 */
	function redeemUnderlying(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		ICToken cToken = ICToken(getCrToken(erc20));
		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		uint256 toBurn = cToken.balanceOf(address(this));
		uint256 tokenToReturn = wmul(toBurn, cToken.exchangeRateCurrent());
		if (tokenToReturn > realAmt) {
			tokenToReturn = realAmt;
		}
		require(
			cToken.redeemUnderlying(tokenToReturn) == 0,
			"something went wrong"
		);

		_sync(erc20);

		uint256 feesPaid = _payFees(erc20, tokenToReturn);

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, tokenToReturn.sub(feesPaid));
		}

		emit LogRedeem(erc20, tokenToReturn);
	}

	/**
	 * @dev borrow ETH/ERC20
	 */
	function borrow(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		ICToken cToken = ICToken(getCrToken(erc20));
		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		enterMarket(address(cToken));
		require(cToken.borrow(tokenAmt) == 0, "got collateral?");

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, realAmt);
		}

		emit LogBorrow(erc20, tokenAmt);
	}

	/**
	 * @dev Pay Debt ETH/ERC20
	 */
	function repay(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		address cErc20 = getCrToken(erc20);
		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		uint256 toRepay;

		if (erc20 == getAddressETH()) {
			ICETH cToken = ICETH(cErc20);
			toRepay = msg.value;
			uint256 borrows = cToken.borrowBalanceCurrent(address(this));
			if (toRepay > borrows) {
				toRepay = borrows;
			}
			cToken.repayBorrow{value: toRepay}();
			emit LogPayback(erc20, toRepay);
		} else {
			ICERC20 cToken = ICERC20(cErc20);
			IERC20 token = IERC20(erc20);
			toRepay = token.balanceOf(address(this));
			uint256 borrows = cToken.borrowBalanceCurrent(address(this));
			if (toRepay > realAmt) {
				toRepay = realAmt;
			}
			if (toRepay > borrows) {
				toRepay = borrows;
			}
			IERC20(erc20).universalApprove(cErc20, toRepay);
			require(cToken.repayBorrow(toRepay) == 0, "transfer approved?");
			emit LogPayback(erc20, toRepay);
		}

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, toRepay);
		}
	}
}

contract CreamLogic is CreamResolver {
	receive() external payable {}
}
