// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import {IHarvester} from "../interfaces/IHarvester.sol";
import {IVault} from "../interfaces/IVault.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Gelato {
	using SafeMath for uint256;

	function checker(IHarvester harvester, IVault vault)
		external
		view
		returns (bool canExec, bytes memory execPayload)
	{
		uint256 delay = harvester.delay();

		canExec = block.timestamp >= vault.lastDistribution().add(delay);

		execPayload = abi.encodeWithSelector(
			IHarvester.harvestVault.selector,
			address(vault)
		);
	}
}
