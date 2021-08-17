// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveIncentives {
	function REWARD_TOKEN() external view returns (address);

	function getRewardsBalance(address[] calldata assets, address user)
		external
		view
		returns (uint256);

	function assets(address aToken)
		external
		view
		returns (
			uint128 emissionPerSecond,
			uint128 lastUpdateTimestamp,
			uint256 index
		);

	function getUserUnclaimedRewards(address _user)
		external
		view
		returns (uint256);

	function claimRewards(
		address[] calldata assets,
		uint256 amount,
		address to
	) external returns (uint256);
}
