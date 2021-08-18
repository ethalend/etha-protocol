//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {
	function MAX_FEE() external view returns (uint256);

	function getVaultFee(address _vault) external view returns (uint256);

	function setVaultFee(address _vault, uint256 _fee) external;

	function getLendingFee(address _asset) external view returns (uint256);

	function setLendingFee(address _asset, uint256 _fee) external;
}
