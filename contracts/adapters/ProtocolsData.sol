//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;

import "../interfaces/ILendingPool.sol";
import "../interfaces/IMemory.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/IAaveAddressProvider.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IProtocolDataProvider {
	function getReserveData(address asset)
		external
		view
		returns (
			uint256 availableLiquidity,
			uint256 totalStableDebt,
			uint256 totalVariableDebt,
			uint256 liquidityRate,
			uint256 variableBorrowRate
		);
}

contract ProtocolsData {
	using SafeMath for uint256;

	IMemory memoryContract;

	mapping(address => address) internal cTokens;
	mapping(address => uint256) internal dydxMarkets;

	address internal constant MATIC =
		0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant WMATIC =
		0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

	IProtocolDataProvider aaveDataProviderV2 =
		IProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);

	struct Data {
		uint256 liquidity;
		uint256 supplyRate;
		uint256 borrowRate;
		uint256 utilizationRate;
	}

	struct DydxData {
		uint256 market;
		uint256 supply;
		uint256 borrow;
	}

	struct Rate {
		uint256 value;
	}

	constructor(IMemory _memoryContract) {
		memoryContract = _memoryContract;
	}

	function getCreamData(address token) public view returns (Data memory) {
		ICToken cToken = ICToken(memoryContract.getCrToken(token));

		uint256 supplyRate = cToken.supplyRatePerBlock();
		uint256 borrowRate = cToken.borrowRatePerBlock();
		uint256 liquidity = cToken.getCash();
		uint256 reserves = cToken.totalReserves();
		uint256 totalBorrows = cToken.totalBorrows();

		uint256 utilizationRate = totalBorrows.mul(1 ether).div(
			liquidity.add(totalBorrows).sub(reserves)
		);

		return Data(liquidity, supplyRate, borrowRate, utilizationRate);
	}

	function getAaveData(address token) public view returns (Data memory) {
		(
			uint256 liquidity,
			,
			uint256 totalBorrows,
			uint256 supplyRate,
			uint256 borrowRate
		) = aaveDataProviderV2.getReserveData(token);

		uint256 utilizationRate = totalBorrows.mul(1 ether).div(
			liquidity.add(totalBorrows)
		);

		return Data(liquidity, supplyRate, borrowRate, utilizationRate);
	}

	function getProtocolsData(address token)
		external
		view
		returns (Data memory aave, Data memory cream)
	{
		aave = getAaveData(token);
		cream = getCreamData(token);
	}
}
