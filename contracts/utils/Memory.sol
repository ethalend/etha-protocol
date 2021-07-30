//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Memory is Ownable {
	mapping(address => address) aTokens;
	mapping(address => address) crTokens;
	mapping(uint256 => uint256) values;

	function getUint(uint256 id) external view returns (uint256) {
		return values[id];
	}

	function setUint(uint256 id, uint256 _value) external {
		values[id] = _value;
	}

	function getAToken(address asset) external view returns (address) {
		return aTokens[asset];
	}

	function setAToken(address asset, address _aToken) external onlyOwner {
		aTokens[asset] = _aToken;
	}

	function getCrToken(address asset) external view returns (address) {
		return crTokens[asset];
	}

	function setCrToken(address asset, address _crToken) external onlyOwner {
		crTokens[asset] = _crToken;
	}
}
