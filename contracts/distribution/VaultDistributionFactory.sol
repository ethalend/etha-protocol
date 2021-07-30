//SPDX-License-Identifier: MIT
pragma solidity 0.5.17;

import "./VaultDistributionRewards.sol";

contract VaultDistributionFactory is Ownable {
	// immutables
	address public rewardsToken;
	uint256 public stakingRewardsGenesis;

	// the staking tokens for which the rewards contract has been deployed
	address[] public stakingTokens;

	// info about rewards for a particular staking token
	struct StakingRewardsInfo {
		address stakingRewards;
		uint256 rewardAmount;
		uint256 endTime;
	}

	// rewards info by staking token
	mapping(address => StakingRewardsInfo)
		public stakingRewardsInfoByStakingToken;

	constructor(address _rewardsToken, uint256 _stakingRewardsGenesis)
		public
		Ownable()
	{
		require(
			_stakingRewardsGenesis >= block.timestamp,
			"StakingRewardsFactory::constructor: genesis too soon"
		);
		require(
			_rewardsToken != address(0),
			"rewards tokend cannot be zero address"
		);
		rewardsToken = _rewardsToken;
		stakingRewardsGenesis = _stakingRewardsGenesis;
	}

	///// permissioned functions

	// deploy a staking reward contract for the staking token, and store the reward amount
	// the reward will be distributed to the staking reward contract no sooner than the genesis
	function deploy(
		address stakingToken,
		uint256 rewardAmount,
		address vault,
		uint256 endTime
	) public onlyOwner {
		StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
			stakingToken
		];
		require(
			info.stakingRewards == address(0),
			"StakingRewardsFactory::deploy: already deployed"
		);

		info.stakingRewards = address(
			new VaultDistributionRewards(
				/*_rewardsDistribution=*/
				address(this),
				rewardsToken,
				vault,
				owner()
			)
		);
		info.rewardAmount = rewardAmount;
		info.endTime = endTime;
		stakingTokens.push(stakingToken);
	}

	// updates the rerward amount and endTime for the distribution contract
	function updateRewards(
		address stakingToken,
		uint256 rewardAmount,
		uint256 endTime
	) public onlyOwner {
		require(
			stakingToken != address(0),
			"staking tokend cannot be zero address"
		);
		StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
			stakingToken
		];
		info.rewardAmount = rewardAmount;
		info.endTime = endTime;
	}

	///// permissionless functions

	// call notifyRewardAmount for all staking tokens.
	function notifyRewardAmounts() public {
		require(
			stakingTokens.length > 0,
			"StakingRewardsFactory::notifyRewardAmounts: called before any deploys"
		);
		for (uint256 i = 0; i < stakingTokens.length; i++) {
			notifyRewardAmount(stakingTokens[i]);
		}
	}

	// notify reward amount for an individual staking token.
	// this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
	function notifyRewardAmount(address stakingToken) public {
		require(
			block.timestamp >= stakingRewardsGenesis,
			"StakingRewardsFactory::notifyRewardAmount: not ready"
		);

		StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
			stakingToken
		];
		require(
			info.stakingRewards != address(0),
			"StakingRewardsFactory::notifyRewardAmount: not deployed"
		);

		if (info.rewardAmount > 0) {
			uint256 rewardAmount = info.rewardAmount;
			info.rewardAmount = 0;

			require(
				IERC20(rewardsToken).transfer(
					info.stakingRewards,
					rewardAmount
				),
				"StakingRewardsFactory::notifyRewardAmount: transfer failed"
			);
			VaultDistributionRewards(info.stakingRewards).notifyRewardAmount(
				rewardAmount,
				info.endTime
			);
		}
	}

	function sweep(
		address recipient,
		address erc20,
		uint256 transferAmount
	) public onlyOwner {
		require(recipient != address(0), "CANNOT TRANSFER TO ZERO ADDRESS");
		require(transferAmount > 0, "TRANSFER AMOUNT 0");
		require(
			IERC20(erc20).transfer(recipient, transferAmount),
			"StakingRewardsFactory::sweep: transfer failed"
		);
	}
}
