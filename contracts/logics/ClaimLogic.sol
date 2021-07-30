//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IProtocolDistribution.sol";
import "../interfaces/IDistributionFactory.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IWallet.sol";
import "../interfaces/IAaveIncentives.sol";

/**
 * @title Claim ETHA rewards for interacting with Lending Protocols
 */
contract ClaimLogic {
	/**
	 * @dev get vault distribution factory address
	 */
	function getVaultDistributionFactory() public pure returns (address) {
		return 0xdB05A386810c809aD5a77422eb189D36c7f24402;
	}

	/**
	 * @dev get Aave MATIC incentives distribution contract
	 */
	function getAaveIncentivesAddress() public pure returns (address) {
		return 0x357D51124f59836DeD84c8a1730D72B749d8BC23;
	}

	/**
	 * @dev get lending distribution contract address
	 */
	function getLendingDistributionAddress(address token)
		public
		view
		returns (address)
	{
		return
			IRegistry(IWallet(address(this)).registry()).distributionContract(
				token
			);
	}

	/**
	 * @notice read aave rewards in MATIC
	 */
	function getRewardsAave(address[] memory tokens)
		external
		view
		returns (uint256)
	{
		return
			IAaveIncentives(getAaveIncentivesAddress()).getRewardsBalance(
				tokens,
				address(this)
			);
	}

	/**
	 * @notice read lending rewards in ETHA
	 */
	function getRewardsLending(address erc20) external view returns (uint256) {
		return
			IProtocolDistribution(getLendingDistributionAddress(erc20)).earned(
				address(this)
			);
	}

	/**
	 * @notice read vaults rewards in ETHA
	 */
	function getRewardsVaults(address erc20) external view returns (uint256) {
		address dist = IDistributionFactory(getVaultDistributionFactory())
		.stakingRewardsInfoByStakingToken(erc20);

		return IProtocolDistribution(dist).earned(address(this));
	}

	/**
	 * @notice claim vault ETHA rewards
	 */
	function claimRewardsVaults(address erc20) external {
		address dist = IDistributionFactory(getVaultDistributionFactory())
		.stakingRewardsInfoByStakingToken(erc20);

		IProtocolDistribution(dist).getReward(address(this));
	}

	/**
	 * @notice claim lending ETHA rewards
	 */
	function claimRewardsLending(address erc20) external {
		IProtocolDistribution(getLendingDistributionAddress(erc20)).getReward(
			address(this)
		);
	}

	/**
	 * @notice claim Aave MATIC rewards
	 */
	function claimAaveRewards(address[] calldata tokens, uint256 amount)
		external
	{
		IAaveIncentives(getAaveIncentivesAddress()).claimRewards(
			tokens,
			amount,
			address(this)
		);
	}
}
