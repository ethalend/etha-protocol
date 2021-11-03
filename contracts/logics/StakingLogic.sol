//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IStakingRewards.sol";
import "../interfaces/IDragonLair.sol";
import "../libs/UniversalERC20.sol";
import "./Helpers.sol";

/**
 * @title Interact with staking contracts
 */
contract StakingLogic is Helpers {
	using SafeMath for uint256;
	using UniversalERC20 for IERC20;

	event Staked(address indexed erc20, uint256 tokenAmt);
	event Unstaked(address indexed erc20, uint256 tokenAmt);
	event Claimed(address indexed erc20, uint256 tokenAmt);

	address public constant ETHA = 0x59E9261255644c411AfDd00bD89162d09D862e38;
	address public constant QUICK = 0x831753DD7087CaC61aB5644b308642cc1c33Dc13;
	address public constant DQUICK = 0xf28164A485B0B2C90639E47b0f377b4a438a16B1;

	function stake(
		address stakingContract,
		address erc20,
		uint256 amount,
		uint256 getId
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId) : amount;

		IERC20(erc20).universalApprove(stakingContract, realAmt);
		IStakingRewards(stakingContract).stake(realAmt);

		emit Staked(erc20, realAmt);
	}

	function unstake(
		address stakingContract,
		address erc20,
		uint256 amount,
		uint256 getId
	) external payable {
		uint256 realAmt = getId > 0 ? getUint(getId) : amount;

		IStakingRewards(stakingContract).withdraw(realAmt);

		emit Unstaked(erc20, realAmt);
	}

	function claim(address stakingContract, uint256 setId) external payable {
		address rewardsToken = IStakingRewards(stakingContract).rewardsToken();
		uint256 initialBal = IERC20(rewardsToken).balanceOf(address(this));

		IStakingRewards(stakingContract).getReward();

		uint256 claimed = IERC20(rewardsToken).balanceOf(address(this)).sub(
			initialBal
		);

		if (claimed > 0) {
			// If claiming dQUICK, unstake from Dragon Lair
			if (rewardsToken == DQUICK) {
				uint256 initialQuick = IERC20(QUICK).balanceOf(address(this));
				IDragonLair(DQUICK).leave(claimed);
				claimed = IERC20(QUICK).balanceOf(address(this)).sub(
					initialQuick
				);
				rewardsToken = QUICK;
			}
			emit Claimed(rewardsToken, claimed);
		}

		// set destTokens received
		if (setId > 0) {
			setUint(setId, claimed);
		}
	}
}
