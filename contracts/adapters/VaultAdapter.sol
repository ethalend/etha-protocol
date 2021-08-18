//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IUniswapV2ERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ICurvePool.sol";
import "../interfaces/IDistribution.sol";
import "../interfaces/IStrat2.sol";
import "../interfaces/IAaveIncentives.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/IMemory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "hardhat/console.sol";

contract VaultAdapter is OwnableUpgradeable {
	using SafeMath for uint256;

	mapping(address => address) public priceFeeds;

	mapping(address => address) public curvePools;

	struct VaultInfo {
		address depositToken;
		address rewardsToken;
		address strategy;
		address distribution;
		address stakingContract;
		uint256 totalDeposits;
		uint256 totalDepositsUSD;
		uint256 ethaRewardsRate;
	}

	function initialize(address[] memory tokens, address[] memory feeds)
		public
		initializer
	{
		for (uint256 i = 0; i < tokens.length; i++) {
			priceFeeds[tokens[i]] = feeds[i];
		}
	}

	function getAaveIncentivesAddress() public pure returns (address) {
		return 0x357D51124f59836DeD84c8a1730D72B749d8BC23;
	}

	function getMemoryAddress() public pure returns (address) {
		return 0x7f3584b047e3c23fC7fF1Fb2aC55130ac2162e20;
	}

	function setPriceFeed(address token, address feed) external {
		priceFeeds[token] = feed;
	}

	function setCurvePool(address lpToken, address pool) external {
		curvePools[lpToken] = pool;
	}

	function formatDecimals(address token, uint256 amount)
		public
		view
		returns (uint256)
	{
		uint256 decimals = IERC20Metadata(token).decimals();

		if (decimals == 18) return amount;
		else return amount.mul(1 ether).div(10**decimals);
	}

	function getQuickswapBalance(address _pair, uint256 lpBalance)
		public
		view
		returns (
			uint256 totalSupply,
			uint256 totalMarket,
			uint256 lpValueUSD
		)
	{
		IUniswapV2ERC20 pair = IUniswapV2ERC20(_pair);

		(uint112 _reserve0, uint112 _reserve1, ) = pair.getReserves();

		totalSupply = pair.totalSupply();

		address token0 = pair.token0();
		address token1 = pair.token1();

		(, int256 token0Price, , , ) = AggregatorV3Interface(priceFeeds[token0])
			.latestRoundData();
		(, int256 token1Price, , , ) = AggregatorV3Interface(priceFeeds[token1])
			.latestRoundData();

		totalMarket = uint256(
			formatDecimals(token0, _reserve0).mul(uint256(token0Price)).div(
				10**8
			)
		).add(
				uint256(formatDecimals(token1, _reserve1))
					.mul(uint256(token1Price))
					.div(10**8)
			);

		lpValueUSD = lpBalance.mul(totalMarket).div(totalSupply);
	}

	function getVaultInfo(IVault vault, bool isQuick)
		external
		view
		returns (VaultInfo memory info)
	{
		info.depositToken = address(vault.underlying());
		info.rewardsToken = address(vault.target());
		info.strategy = address(vault.strat());
		info.distribution = vault.distribution();
		info.totalDeposits = vault.calcTotalValue();
		IDistribution dist = IDistribution(info.distribution);
		info.ethaRewardsRate = address(dist) == address(0)
			? 0
			: dist.rewardRate();

		if (isQuick) {
			(, , uint256 usdValue) = getQuickswapBalance(
				info.depositToken,
				info.totalDeposits
			);
			info.totalDepositsUSD = usdValue;
			info.stakingContract = IStrat2(info.strategy).staking();
		} else {
			info.totalDepositsUSD = info
				.totalDeposits
				.mul(
					ICurvePool(curvePools[info.depositToken])
						.get_virtual_price()
				)
				.div(1 ether);

			info.stakingContract = IStrat2(info.strategy).gauge();
		}
	}

	function getAaveRewards(address[] memory _tokens)
		public
		view
		returns (uint256[] memory)
	{
		IAaveIncentives incentives = IAaveIncentives(
			getAaveIncentivesAddress()
		);

		uint256[] memory _rewards = new uint256[](_tokens.length);

		for (uint256 i = 0; i < _tokens.length; i++) {
			IAToken aToken = IAToken(
				IMemory(getMemoryAddress()).getAToken(_tokens[i])
			);

			uint256 totalSupply = formatDecimals(
				address(aToken),
				aToken.totalSupply()
			);

			(uint256 emissionPerSecond, , ) = incentives.assets(
				address(aToken)
			);

			(, int256 maticPrice, , , ) = AggregatorV3Interface(
				priceFeeds[0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE]
			).latestRoundData();
			(, int256 tokenPrice, , , ) = AggregatorV3Interface(
				priceFeeds[_tokens[i]]
			).latestRoundData();

			_rewards[i] = emissionPerSecond
				.mul(uint256(maticPrice))
				.mul(365 days)
				.mul(1 ether)
				.div(totalSupply)
				.div(uint256(tokenPrice));
		}

		return _rewards;
	}
}
