//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
	mapping(address => uint256) vaults;
	mapping(address => uint256) lending;

	function getVaultFee(address _vault) external view returns (uint256) {
		return vaults[_vault];
	}

	function setVaultFee(address _vault, uint256 _fee) external onlyOwner {
		vaults[_vault] = _fee;
	}

	function getLendingFee(address _asset) external view returns (uint256) {
		return lending[_asset];
	}

	function setLendingFee(address _asset, uint256 _fee) external onlyOwner {
		lending[_asset] = _fee;
	}
}
