//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICERC20 {
	function mint(uint256 mintAmount) external returns (uint256); // For ERC20

	function repayBorrow(uint256 repayAmount) external returns (uint256); // For ERC20

	function repayBorrowBehalf(address borrower, uint256 repayAmount)
		external
		returns (uint256); // For ERC20

	function borrowBalanceCurrent(address account) external returns (uint256);

	function underlying() external view returns (address);
}
