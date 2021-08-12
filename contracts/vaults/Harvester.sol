//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "../interfaces/IVault.sol";
import "../interfaces/IUniswapV2Router.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Harvester is Ownable {
	using SafeMath for uint256;

	event Harvested(address indexed vault, address indexed sender);

	// Quickswap Router
	IUniswapV2Router constant ROUTER =
		IUniswapV2Router(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

	uint256 public delay;

	constructor(uint256 _delay) {
		delay = _delay;
	}

	modifier onlyAfterDelay(IVault vault) {
		require(
			block.timestamp >= vault.lastDistribution().add(delay),
			"Not ready to harvest"
		);
		_;
	}

	/**
		@notice Harvest vault using uniswap
		@dev any user can harvest after delay has passed
	*/
	function harvestVault(IVault vault) public onlyAfterDelay(vault) {
		// Amount to Harvest
		uint256 afterFee = vault.harvest();
		require(afterFee > 0, "!Yield");

		IERC20 from = vault.rewards();
		IERC20 to = vault.target();

		// Uniswap path
		address[] memory path = new address[](2);
		path[0] = address(from);
		path[1] = address(to);

		// Swap underlying to target
		from.approve(address(ROUTER), afterFee);
		uint256 received = ROUTER.swapExactTokensForTokens(
			afterFee,
			1,
			path,
			address(this),
			block.timestamp + 1
		)[path.length - 1];

		// Send profits to vault
		to.approve(address(vault), received);
		vault.distribute(received);

		emit Harvested(address(vault), msg.sender);
	}

	/**
		@dev update delay required to harvest vault
	*/
	function setDelay(uint256 _delay) external onlyOwner {
		delay = _delay;
	}

	// no tokens should ever be stored on this contract. Any tokens that are sent here by mistake are recoverable by the owner
	function sweep(address _token) external onlyOwner {
		IERC20(_token).transfer(
			owner(),
			IERC20(_token).balanceOf(address(this))
		);
	}
}
