//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDistributionFactory {
	function stakingRewardsInfoByStakingToken(address erc20)
		external
		view
		returns (address);
}
