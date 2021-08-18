//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IWETH.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IAaveAddressProvider.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/IWallet.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IMemory.sol";
import "../interfaces/IProtocolDistribution.sol";
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

contract AaveHelpers is DSMath {
	using UniversalERC20 for IERC20;

	/**
	 * @dev get ethereum address
	 */
	function getAddressETH() public pure returns (address eth) {
		eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	}

	/**
	 * @dev get Aave Lending Pool Address V2
	 */
	function getLendingPoolAddress()
		public
		view
		returns (address lendingPoolAddress)
	{
		IAaveAddressProvider adr = IAaveAddressProvider(
			0xd05e3E715d945B59290df0ae8eF85c1BdB684744
		);
		return adr.getLendingPool();
	}

	function getWMATIC() public pure returns (address) {
		return 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
	}

	function getReferralCode() public pure returns (uint16) {
		return uint16(0);
	}

	function _stake(address erc20, uint256 amount) internal {
		// Add same amount to distribution contract
		address distribution = IRegistry(IWallet(address(this)).registry())
			.distributionContract(erc20);
		if (distribution != address(0)) {
			IProtocolDistribution(distribution).stake(amount);
		}
	}

	function _unstake(address erc20, uint256 amount) internal {
		address distribution = IRegistry(IWallet(address(this)).registry())
			.distributionContract(erc20);

		if (distribution != address(0)) {
			uint256 maxWithdrawalAmount = IProtocolDistribution(distribution)
				.balanceOf(address(this));

			uint256 toWithdraw = amount > maxWithdrawalAmount
				? maxWithdrawalAmount
				: amount;

			if (toWithdraw > 0) {
				IProtocolDistribution(distribution).withdraw(toWithdraw);
			}
		}
	}

	function _payFees(address erc20, uint256 amt) internal {
		(uint256 fee, uint256 maxFee, address feeRecipient) = getLendingFee(
			erc20
		);

		if (fee > 0) {
			require(feeRecipient != address(0), "ZERO ADDRESS");

			IERC20(erc20).universalTransfer(
				feeRecipient,
				div(mul(amt, fee), maxFee)
			);
		}
	}
}

contract AaveResolver is AaveHelpers {
	using SafeMath for uint256;
	using UniversalERC20 for IERC20;

	event LogMint(address indexed erc20, uint256 tokenAmt);
	event LogRedeem(address indexed erc20, uint256 tokenAmt);
	event LogBorrow(address indexed erc20, uint256 tokenAmt);
	event LogPayback(address indexed erc20, uint256 tokenAmt);

	/**
	 * @dev Deposit MATIC/ERC20 and mint Aave V2 Tokens
	 * @param erc20 underlying asset to deposit
	 * @param tokenAmt amount of underlying asset to deposit
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of aTokens minted in memory contract
	 */
	function mintAToken(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		address aToken = getAToken(erc20);
		uint256 initialBal = IERC20(aToken).universalBalanceOf(address(this));

		require(aToken != address(0), "INVALID ASSET");

		require(
			realAmt > 0 &&
				realAmt <= IERC20(erc20).universalBalanceOf(address(this)),
			"INVALID AMOUNT"
		);

		address realToken = erc20;

		if (erc20 == getAddressETH()) {
			IWETH(getWMATIC()).deposit{value: realAmt}();
			realToken = getWMATIC();
		}

		ILendingPool _lendingPool = ILendingPool(getLendingPoolAddress());

		IERC20(realToken).universalApprove(address(_lendingPool), realAmt);

		_lendingPool.deposit(
			realToken,
			realAmt,
			address(this),
			getReferralCode()
		);

		_stake(erc20, realAmt);

		// set aTokens received
		if (setId > 0) {
			setUint(
				setId,
				IERC20(aToken).universalBalanceOf(address(this)).sub(initialBal)
			);
		}

		emit LogMint(erc20, realAmt);
	}

	/**
	 * @dev Redeem MATIC/ERC20 and burn Aave V2 Tokens
	 * @param erc20 underlying asset to redeem
	 * @param tokenAmt Amount of underling tokens
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of tokens redeemed in memory contract
	 */
	function redeemAToken(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external {
		IAToken aToken = IAToken(getAToken(erc20));
		require(address(aToken) != address(0), "INVALID ASSET");

		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		require(realAmt > 0, "ZERO AMOUNT");
		require(realAmt <= aToken.balanceOf(address(this)), "INVALID AMOUNT");

		ILendingPool _lendingPool = ILendingPool(getLendingPoolAddress());
		_lendingPool.withdraw(erc20, realAmt, address(this));

		_payFees(erc20, realAmt);
		_unstake(erc20, realAmt);

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, IERC20(erc20).universalBalanceOf(address(this)));
		}

		emit LogRedeem(erc20, realAmt);
	}

	/**
	 * @dev Redeem MATIC/ERC20 and burn Aave Tokens
	 * @param erc20 Address of the underlying token to borrow
	 * @param tokenAmt Amount of underlying tokens to borrow
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of tokens borrowed in memory contract
	 */
	function borrow(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		address realToken = erc20 == getAddressETH() ? getWMATIC() : erc20;

		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		ILendingPool(getLendingPoolAddress()).borrow(
			realToken,
			realAmt,
			2,
			getReferralCode(),
			address(this)
		);

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, realAmt);
		}

		emit LogBorrow(erc20, realAmt);
	}

	/**
	 * @dev Redeem MATIC/ERC20 and burn Aave Tokens
	 * @param erc20 Address of the underlying token to repay
	 * @param tokenAmt Amount of underlying tokens to repay
	 * @param getId read value of tokenAmt from memory contract
	 * @param setId set value of tokens repayed in memory contract
	 */
	function repay(
		address erc20,
		uint256 tokenAmt,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		address realToken = erc20;

		uint256 realAmt = getId > 0 ? div(getUint(getId), divider) : tokenAmt;

		if (erc20 == getAddressETH()) {
			IWETH(getWMATIC()).deposit{value: realAmt}();
			realToken = getWMATIC();
		}

		IERC20(realToken).universalApprove(getLendingPoolAddress(), realAmt);

		ILendingPool(getLendingPoolAddress()).repay(
			realToken,
			realAmt,
			2,
			address(this)
		);

		// set amount of tokens received
		if (setId > 0) {
			setUint(setId, realAmt);
		}

		emit LogPayback(erc20, realAmt);
	}
}

contract AaveLogic is AaveResolver {
	receive() external payable {}
}
