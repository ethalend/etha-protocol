//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IUniswapV2ERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/ICurvePool.sol";
import "../interfaces/IDistribution.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract VaultAdapter is OwnableUpgradeable {
	using SafeMath for uint256;

	mapping(address => address) public priceFeeds;

	mapping(address => address) public curvePools;

	struct VaultInfo {
		address depositToken;
		address rewardsToken;
		address strategy;
		address distribution;
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

		if (isQuick) {
			(, , uint256 usdValue) = getQuickswapBalance(
				info.depositToken,
				info.totalDeposits
			);
			info.totalDepositsUSD = usdValue;
		} else
			info.totalDepositsUSD = info
				.totalDeposits
				.mul(
					ICurvePool(curvePools[info.depositToken])
						.get_virtual_price()
				)
				.div(1 ether);
		IDistribution dist = IDistribution(info.distribution);
		info.ethaRewardsRate = address(dist) == address(0)
			? 0
			: dist.rewardRate();
	}
}
