//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICETH {
	function mintNative() external payable; // For ETH

	function repayBorrow() external payable; // For ETH

	function repayBorrowBehalf(address borrower) external payable; // For ETH

	function borrowBalanceCurrent(address account) external returns (uint256);
}
