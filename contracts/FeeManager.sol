//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeeManager is Ownable {
	uint256 public constant MAX_FEE = 10000;

	mapping(address => uint256) vaults;
	mapping(address => uint256) lending;

	function getVaultFee(address _vault) external view returns (uint256) {
		return vaults[_vault];
	}

	function setVaultFee(address _vault, uint256 _fee) external onlyOwner {
		require(_fee <= MAX_FEE);
		vaults[_vault] = _fee;
	}

	function setVaultFeeMulti(address[] memory _vaults, uint256[] memory _fees)
		external
		onlyOwner
	{
		require(_vaults.length == _fees.length, "!LENGTH");
		for (uint256 i = 0; i < _vaults.length; i++) {
			require(_fees[i] <= MAX_FEE);
			vaults[_vaults[i]] = _fees[i];
		}
	}

	function getLendingFee(address _asset) external view returns (uint256) {
		return lending[_asset];
	}

	function setLendingFee(address _asset, uint256 _fee) external onlyOwner {
		lending[_asset] = _fee;
	}

	function setLendingFeeMulti(
		address[] memory _assets,
		uint256[] memory _fees
	) external onlyOwner {
		require(_assets.length == _fees.length, "!LENGTH");
		for (uint256 i = 0; i < _assets.length; i++) {
			require(_fees[i] <= MAX_FEE);
			lending[_assets[i]] = _fees[i];
		}
	}
}
