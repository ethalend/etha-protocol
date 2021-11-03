//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
	function enterMarkets(address[] calldata cTokens)
		external
		returns (uint256[] memory);

	function exitMarket(address cTokenAddress) external returns (uint256);

	function getAssetsIn(address account)
		external
		view
		returns (address[] memory);

	function getAccountLiquidity(address account)
		external
		view
		returns (
			uint256,
			uint256,
			uint256
		);

	function markets(address cTokenAddress)
		external
		view
		returns (
			bool,
			uint256,
			uint8
		);
}
