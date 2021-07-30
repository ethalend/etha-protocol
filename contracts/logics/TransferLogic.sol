//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IRegistry.sol";
import "../interfaces/IWallet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TransferLogic {
	event LogDeposit(address indexed erc20, uint256 tokenAmt);
	event LogWithdraw(address indexed erc20, uint256 tokenAmt);

	/**
	 * @dev get ethereum address
	 */
	function getAddressETH() public pure returns (address eth) {
		eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
	}

	/**
	 * @dev Deposit ERC20 from user
	 * @dev user must approve token transfer first
	 */
	function deposit(address erc20, uint256 amount) external payable {
		require(amount > 0, "ZERO-AMOUNT");
		if (erc20 != getAddressETH()) {
			IERC20(erc20).transferFrom(msg.sender, address(this), amount);
		}

		emit LogDeposit(erc20, amount);
	}

	/**
	 * @dev Withdraw ETH/ERC20 to user
	 */
	function withdraw(address erc20, uint256 amount) external {
		address registry = IWallet(address(this)).registry();

		require(
			!IRegistry(registry).notAllowed(erc20),
			"Token withdraw not allowed"
		);

		if (erc20 == getAddressETH()) {
			payable(msg.sender).transfer(amount);
		} else {
			IERC20(erc20).transfer(msg.sender, amount);
		}

		emit LogWithdraw(erc20, amount);
	}

	/**
	 * @dev Remove ERC20 approval to certain target
	 */
	function removeApproval(address erc20, address target) external {
		if (erc20 != getAddressETH()) {
			IERC20(erc20).approve(target, 0);
		}
	}
}
