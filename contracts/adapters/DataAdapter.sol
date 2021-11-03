//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/ICToken.sol";
import "../interfaces/IProtocolDataProvider.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/IMemory.sol";
import "../interfaces/IComptroller.sol";

contract DataAdapter {
	using SafeMath for uint256;
	IProtocolDataProvider protocolData =
		IProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);
	IComptroller compTroller =
		IComptroller(0x20CA53E2395FA571798623F1cFBD11Fe2C114c24);
	ILendingPool lendingPool;
	IMemory memoryContract;

	/**
		@dev Struct for the user data in aave.
	**/
	struct UserDataAave {
		uint256 totalCollateralETH;
		uint256 totalDebtETH;
		uint256 availableBorrowsETH;
		uint256 currentLiquidationThreshold;
		uint256 ltv;
		uint256 healthFactor;
	}

	/**
		@dev Struct for the asset data in aave.
	**/
	struct AssetDataAave {
		uint256 availableLiquidity;
		uint256 totalVariableDebt;
		uint256 liquidityRate;
		uint256 variableBorrowRate;
		uint256 ltv;
		uint256 liquidationThreshold;
	}

	/**
		@dev Struct for the user data in aave.
	**/
	struct UserDataCream {
		uint256 totalCollateralETH;
		uint256 totalDebtETH;
		uint256 availableBorrowsETH;
		uint256 currentLiquidationThreshold;
		uint256 ltv;
		uint256 healthFactor;
	}

	/**
		@dev Struct for the asset data in cream.
	**/
	struct AssetDataCream {
		uint256 availableLiquidity;
		uint256 totalVariableDebt;
		uint256 liquidityRate;
		uint256 variableBorrowRate;
		uint256 liquidationThreshold;
		uint256 ltv;
	}

	/**
		@dev Struct for the all the information of the asset in both protocols.
	**/
	struct DataAssetOfProtocols {
		AssetDataAave dataAssetAave;
		AssetDataCream dataAssetCream;
	}

	/**
		@dev Struct for the all the information of the user in both protocols.
	**/
	struct DataUserOfProtocols {
		UserDataAave dataUserAave;
		UserDataCream dataUserCream;
	}

	constructor(ILendingPool _lendingPool, IMemory _memoryContract) {
		lendingPool = _lendingPool;
		memoryContract = _memoryContract;
	}

	/**
		@dev Get all the data from a lendingPool for a
		specific user.
		@param _user the user that we want to get the data.
	**/
	function getDataForUserAave(address _user)
		public
		view
		returns (UserDataAave memory data)
	{
		(
			uint256 totalCollateralETH,
			uint256 totalDebtETH,
			uint256 availableBorrowsETH,
			uint256 currentLiquidationThreshold,
			uint256 ltv,
			uint256 healthFactor
		) = lendingPool.getUserAccountData(_user);

		data = UserDataAave(
			totalCollateralETH,
			totalDebtETH,
			availableBorrowsETH,
			currentLiquidationThreshold,
			ltv,
			healthFactor
		);
	}

	/**
		@dev Get all the data from a lendingPool for a
		specific asset.
		@param _asset the asset that we want to get the data.
	**/
	function getDataForAssetAave(address _asset)
		public
		view
		returns (AssetDataAave memory data)
	{
		(
			uint256 availableLiquidity,
			,
			uint256 totalVariableDebt,
			uint256 liquidityRate,
			uint256 variableBorrowRate,
			,
			,
			,
			,

		) = protocolData.getReserveData(_asset);

		(
			,
			uint256 ltv,
			uint256 liquidationThreshold,
			,
			,
			,
			,
			,
			,

		) = protocolData.getReserveConfigurationData(_asset);

		data = AssetDataAave(
			availableLiquidity,
			totalVariableDebt,
			liquidityRate,
			variableBorrowRate,
			ltv,
			liquidationThreshold
		);
	}

	/**
		@dev Get all the data from a lendingPool for a
		specific user.
		@param _user the user that we want to get the data.
	**/
	function getDataForUserCream(address _user)
		public
		view
		returns (UserDataCream memory data)
	{
		address[] memory assetsIn = compTroller.getAssetsIn(_user);
		uint256 totalSupplyETH;
		uint256 totalDebtETH;
		uint256 ltv;

		for (uint256 tokenIndex; tokenIndex < assetsIn.length; tokenIndex++) {
			ICToken crToken = ICToken(
				memoryContract.getCrToken(assetsIn[tokenIndex])
			);
			totalSupplyETH += crToken.balanceOf(_user);
			totalDebtETH += crToken.borrowBalanceStored(_user);
		}

		if (totalDebtETH != 0) {
			ltv = totalDebtETH.div(totalSupplyETH);
		}

		(, uint256 availableBorrowsETH, ) = compTroller.getAccountLiquidity(
			_user
		);

		data = UserDataCream(
			totalSupplyETH,
			totalDebtETH,
			availableBorrowsETH,
			0,
			ltv,
			0
		);
	}

	/**
		@dev Get all the data from a CToken for a
		specific asset.
		@param _asset the asset that we want to get the data.
	**/
	function getDataForAssetCream(address _asset)
		public
		view
		returns (AssetDataCream memory data)
	{
		ICToken crAsset = ICToken(memoryContract.getCrToken(_asset));
		uint256 availableLiquidity = crAsset.getCash();
		uint256 totalVariableDebt = crAsset.totalBorrows();
		uint256 liquidityRate = crAsset.supplyRatePerBlock();
		uint256 variableBorrowRate = crAsset.borrowRatePerBlock();
		(, uint256 collateralFactor, ) = compTroller.markets(address(crAsset));

		data = AssetDataCream(
			availableLiquidity,
			totalVariableDebt,
			liquidityRate,
			variableBorrowRate,
			0,
			collateralFactor
		);
	}

	/**
		@dev Get the general data of both protocols for the _asset.
		@param _asset asset to get the data from both protocols.
	**/
	function getDataAssetOfProtocols(address _asset)
		public
		view
		returns (DataAssetOfProtocols memory data)
	{
		data = DataAssetOfProtocols(
			getDataForAssetAave(_asset),
			getDataForAssetCream(_asset)
		);
	}

	/**
		@dev Get the general data of both protocols for the _user.
		@param _user user to get the data from both protocols.
	**/
	function getDataUserOfProtocols(address _user)
		public
		view
		returns (DataUserOfProtocols memory data)
	{
		data = DataUserOfProtocols(
			getDataForUserAave(_user),
			getDataForUserCream(_user)
		);
	}
}
