//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Detailed is IERC20 {
	function decimals() external view returns (uint8);
}

interface IVault {
	function totalSupply() external view returns (uint256);

	function harvest() external returns (uint256);

	function distribute(uint256 amount) external;

	function rewards() external view returns (IERC20);

	function underlying() external view returns (IERC20Detailed);

	function target() external view returns (IERC20);

	function harvester() external view returns (address);

	function owner() external view returns (address);

	function distribution() external view returns (address);

	function strat() external view returns (address);

	function timelock() external view returns (address payable);

	function claimOnBehalf(address recipient) external;

	function lastDistribution() external view returns (uint256);

	function performanceFee() external view returns (uint256);

	function balanceOf(address) external view returns (uint256);

	function totalYield() external returns (uint256);

	function calcTotalValue() external view returns (uint256);

	function deposit(uint256 amount) external;

	function depositAndWait(uint256 amount) external;

	function withdraw(uint256 amount) external;

	function withdrawPending(uint256 amount) external;

	function changePerformanceFee(uint256 fee) external;

	function claim() external returns (uint256 claimed);

	function unclaimedProfit(address user) external view returns (uint256);

	function pending(address user) external view returns (uint256);
}
