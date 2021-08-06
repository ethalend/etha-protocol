// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IHarvester {
	function harvestVault(address vault) external;

	function delay() external view returns (uint256);
}
