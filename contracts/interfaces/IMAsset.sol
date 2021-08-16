// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.0;
// pragma abicoder v2;

enum BassetStatus {
	Default,
	Normal,
	BrokenBelowPeg,
	BrokenAbovePeg,
	Blacklisted,
	Liquidating,
	Liquidated,
	Failed
}

struct BassetPersonal {
	// Address of the bAsset
	address addr;
	// Address of the bAsset
	address integrator;
	// An ERC20 can charge transfer fee, for example USDT, DGX tokens.
	bool hasTxFee; // takes a byte in storage
	// Status of the bAsset
	BassetStatus status;
}

struct BassetData {
	// 1 Basset * ratio / ratioScale == x Masset (relative value)
	// If ratio == 10e8 then 1 bAsset = 10 mAssets
	// A ratio is divised as 10^(18-tokenDecimals) * measurementMultiple(relative value of 1 base unit)
	uint128 ratio;
	// Amount of the Basset that is held in Collateral
	uint128 vaultBalance;
}

abstract contract IMasset {
	// Mint
	function mint(
		address _input,
		uint256 _inputQuantity,
		uint256 _minOutputQuantity,
		address _recipient
	) external virtual returns (uint256 mintOutput);

	function mintMulti(
		address[] calldata _inputs,
		uint256[] calldata _inputQuantities,
		uint256 _minOutputQuantity,
		address _recipient
	) external virtual returns (uint256 mintOutput);

	function getMintOutput(address _input, uint256 _inputQuantity)
		external
		view
		virtual
		returns (uint256 mintOutput);

	function getMintMultiOutput(
		address[] calldata _inputs,
		uint256[] calldata _inputQuantities
	) external view virtual returns (uint256 mintOutput);

	// Swaps
	function swap(
		address _input,
		address _output,
		uint256 _inputQuantity,
		uint256 _minOutputQuantity,
		address _recipient
	) external virtual returns (uint256 swapOutput);

	function getSwapOutput(
		address _input,
		address _output,
		uint256 _inputQuantity
	) external view virtual returns (uint256 swapOutput);

	// Redemption
	function redeem(
		address _output,
		uint256 _mAssetQuantity,
		uint256 _minOutputQuantity,
		address _recipient
	) external virtual returns (uint256 outputQuantity);

	function redeemMasset(
		uint256 _mAssetQuantity,
		uint256[] calldata _minOutputQuantities,
		address _recipient
	) external virtual returns (uint256[] memory outputQuantities);

	function redeemExactBassets(
		address[] calldata _outputs,
		uint256[] calldata _outputQuantities,
		uint256 _maxMassetQuantity,
		address _recipient
	) external virtual returns (uint256 mAssetRedeemed);

	function getRedeemOutput(address _output, uint256 _mAssetQuantity)
		external
		view
		virtual
		returns (uint256 bAssetOutput);

	function getRedeemExactBassetsOutput(
		address[] calldata _outputs,
		uint256[] calldata _outputQuantities
	) external view virtual returns (uint256 mAssetAmount);

	// Views
	function getBasket() external view virtual returns (bool, bool);

	function getBasset(address _token)
		external
		view
		virtual
		returns (BassetPersonal memory personal, BassetData memory data);

	function getBassets()
		external
		view
		virtual
		returns (BassetPersonal[] memory personal, BassetData[] memory data);

	function bAssetIndexes(address) external view virtual returns (uint8);

	function getPrice()
		external
		view
		virtual
		returns (uint256 price, uint256 k);

	// SavingsManager
	function collectInterest()
		external
		virtual
		returns (uint256 swapFeesGained, uint256 newSupply);

	function collectPlatformInterest()
		external
		virtual
		returns (uint256 mintAmount, uint256 newSupply);

	// Admin
	function setCacheSize(uint256 _cacheSize) external virtual;

	function setFees(uint256 _swapFee, uint256 _redemptionFee) external virtual;

	function setTransferFeesFlag(address _bAsset, bool _flag) external virtual;

	function migrateBassets(
		address[] calldata _bAssets,
		address _newIntegration
	) external virtual;
}
