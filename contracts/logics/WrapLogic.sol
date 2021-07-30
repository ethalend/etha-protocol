//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IWETH.sol";

contract WrapLogic {
	IWETH internal constant wMatic =
		IWETH(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

	function wrap(uint256 amount) external payable {
		uint256 realAmt = amount == type(uint256).max
			? address(this).balance
			: amount;
		wMatic.deposit{value: realAmt}();
	}

	function unwrap(uint256 amount) external {
		uint256 realAmt = amount == type(uint256).max
			? wMatic.balanceOf(address(this))
			: amount;
		wMatic.withdraw(realAmt);
	}
}
