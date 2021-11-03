//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStakingRewards.sol";
import "../interfaces/IDragonLair.sol";

contract StakingAdapter {
	IDragonLair public constant DQUICK =
		IDragonLair(0xf28164A485B0B2C90639E47b0f377b4a438a16B1);

	address public constant QUICK = 0x831753DD7087CaC61aB5644b308642cc1c33Dc13;

	struct Data {
		address stakingToken;
		address rewardsToken;
		uint256 totalSupply;
		uint256 rewardsRate;
	}

	function getStakingInfo(address[] calldata stakingContracts)
		external
		view
		returns (Data[] memory)
	{
		Data[] memory _datas = new Data[](stakingContracts.length);

		IStakingRewards instance;

		for (uint256 i = 0; i < _datas.length; i++) {
			instance = IStakingRewards(stakingContracts[i]);

			uint256 rewardRate = instance.rewardRate();
			address rewardsToken = instance.rewardsToken();

			// Convert dQUICK for QUICK
			if (instance.rewardsToken() == address(DQUICK)) {
				rewardRate = DQUICK.dQUICKForQUICK(rewardRate);
				rewardsToken = QUICK;
			}

			_datas[i] = Data(
				instance.stakingToken(),
				rewardsToken,
				instance.totalSupply(),
				rewardRate
			);
		}

		return _datas;
	}
}
