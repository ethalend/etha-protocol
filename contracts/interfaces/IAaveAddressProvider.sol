// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveAddressProvider {
	function getLendingPool() external view returns (address);

	function getLendingPoolCore() external view returns (address);
}
