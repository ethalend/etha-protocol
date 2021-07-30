//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStrat {
	function invest() external; // underlying amount must be sent from vault to strat address before

	function divest(uint256 amount) external; // should send requested amount to vault directly, not less or more

	function totalYield() external returns (uint256);

	function calcTotalValue() external view returns (uint256);

	function claim() external returns (uint256 claimed);
}
