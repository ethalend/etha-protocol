//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrat2 {
	function calcTotalValue() external view returns (uint256);

	function totalYield() external view returns (uint256);

	function totalYield2() external view returns (uint256);

	function staking() external view returns (address);

	function gauge() external view returns (address);
}
