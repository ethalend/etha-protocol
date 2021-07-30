//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMemory {
	function getUint(uint256) external view returns (uint256);

	function setUint(uint256 id, uint256 value) external;

	function getAToken(address asset) external view returns (address);

	function setAToken(address asset, address _aToken) external;

	function getCrToken(address asset) external view returns (address);

	function setCrToken(address asset, address _crToken) external;
}
