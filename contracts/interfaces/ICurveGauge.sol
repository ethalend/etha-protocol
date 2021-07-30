// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 0xe381C25de995d62b453aF8B931aAc84fcCaa7A62

interface ICurveGauge {
	function lp_token() external view returns (address);

	function balanceOf(address) external view returns (uint256);

	function reward_tokens(uint256) external view returns (address);

	function claim_rewards() external;

	function deposit(uint256 value) external;

	function withdraw(uint256 value) external;

	function claimable_reward(address user, address token)
		external
		returns (uint256);
}
