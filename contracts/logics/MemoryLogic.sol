//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./Helpers.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title Perform arithmetic actions over stored memory values
 */
contract MemoryLogic is Helpers {
	using SafeMath for uint256;

	/**
	 * @dev get vault distribution factory address
	 */
	function addValues(uint256[] memory ids, uint256 initialVal)
		external
		payable
	{
		uint256 total = initialVal;

		for (uint256 i = 0; i < ids.length; i++) {
			total = total.add(getUint(ids[i]));
		}

		setUint(1, total); // store in first position
	}
}
