//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IMemory.sol";
import "../interfaces/IRegistry.sol";
import "../interfaces/IWallet.sol";

contract Helpers {
	/**
	 * @dev Return Memory Variable Address
	 */
	function getMemoryAddr() public view returns (address) {
		return IRegistry(IWallet(address(this)).registry()).memoryAddr();
	}

	/**
	 * @dev Get Uint value from Memory Contract.
	 */
	function getUint(uint256 id) internal view returns (uint256) {
		return IMemory(getMemoryAddr()).getUint(id);
	}

	/**
	 * @dev Set Uint value in Memory Contract.
	 */
	function setUint(uint256 id, uint256 val) internal {
		IMemory(getMemoryAddr()).setUint(id, val);
	}

	/**
	 * @dev Get aToken address from Memory Contract.
	 */
	function getAToken(address asset) internal view returns (address) {
		return IMemory(getMemoryAddr()).getAToken(asset);
	}

	/**
	 * @dev Get crToken address from Memory Contract.
	 */
	function getCrToken(address asset) internal view returns (address) {
		return IMemory(getMemoryAddr()).getCrToken(asset);
	}
}
