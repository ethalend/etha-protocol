//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Balances {
	address internal constant MATIC =
		0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

	function getBalances(address[] calldata tokens, address user)
		external
		view
		returns (uint256[] memory)
	{
		uint256[] memory balances = new uint256[](tokens.length);

		for (uint256 i = 0; i < tokens.length; i++) {
			if (tokens[i] == MATIC) balances[i] = user.balance;
			else balances[i] = IERC20(tokens[i]).balanceOf(user);
		}

		return balances;
	}
}
