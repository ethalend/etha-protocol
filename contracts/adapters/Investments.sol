//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMemory.sol";
import "../interfaces/ICToken.sol";

interface IProtocolDataProvider {
	function getUserReserveData(address reserve, address user)
		external
		view
		returns (uint256 currentATokenBalance);
}

contract Investments is Ownable {
	using SafeMath for uint256;

	IMemory memoryContract;

	address internal constant MATIC =
		0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	address internal constant WMATIC =
		0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

	IProtocolDataProvider aaveDataProviderV2 =
		IProtocolDataProvider(0x7551b5D2763519d4e37e8B81929D336De671d46d);

	struct Balance {
		uint256 aave;
		uint256 cream;
	}

	constructor(IMemory _memoryContract) {
		memoryContract = _memoryContract;
	}

	function getAaveBalanceV2(address token, address account)
		public
		view
		returns (uint256)
	{
		return
			aaveDataProviderV2.getUserReserveData(
				token == MATIC ? WMATIC : token,
				account
			);
	}

	function getCreamBalance(address token, address user)
		public
		view
		returns (uint256)
	{
		(, uint256 balance, , uint256 rate) = ICToken(
			memoryContract.getCrToken(token)
		).getAccountSnapshot(user);

		return balance.mul(rate).div(1 ether);
	}

	function getBalances(address[] calldata tokens, address user)
		external
		view
		returns (Balance[] memory)
	{
		Balance[] memory balances = new Balance[](tokens.length);

		for (uint256 i = 0; i < tokens.length; i++) {
			balances[i].aave = getAaveBalanceV2(tokens[i], user);
			balances[i].cream = getCreamBalance(tokens[i], user);
		}

		return balances;
	}
}
