//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAToken {
	function redeem(uint256 amount) external;

	function principalBalanceOf(address user) external view returns (uint256);

	function balanceOf(address user) external view returns (uint256);

	function transferFrom(
		address,
		address,
		uint256
	) external returns (bool);

	function transfer(address, uint256) external returns (bool);

	function transferAllowed(address from, uint256 amount)
		external
		returns (bool);

	function underlyingAssetAddress() external pure returns (address);

	function UNDERLYING_ASSET_ADDRESS() external pure returns (address);
}
