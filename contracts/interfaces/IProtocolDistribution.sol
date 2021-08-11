//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IProtocolDistribution {
	function stake(uint256 amount) external;

	function withdraw(uint256 amount) external;

	function getReward(address user) external;

	function earned(address user) external view returns (uint256);

	function balanceOf(address account) external view returns (uint256);

	function rewardsToken() external view returns (address);

	function rewardPerToken() external view returns (uint256);
}
