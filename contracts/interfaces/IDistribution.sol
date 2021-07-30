//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDistribution {
	function stake(address user, uint256 redeemTokens) external;

	function withdraw(address user, uint256 redeemAmount) external;

	function getReward(address user) external;

	function balanceOf(address account) external view returns (uint256);
}
