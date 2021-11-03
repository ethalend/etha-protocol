//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IUniswapV2Router.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IWETH.sol";
import "../libs/UniversalERC20.sol";
import "./Helpers.sol";
import "hardhat/console.sol";

contract SushiswapResolver is Helpers {
	using SafeMath for uint256;
	using UniversalERC20 for IERC20;
	using UniversalERC20 for IWETH;

	/**
		@dev This is the address of the router of SushiSwap: SushiV2Router02. 
	**/
	IUniswapV2Router internal constant router =
		IUniswapV2Router(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

	/**
		@dev This is the address of the factory of SushiSwap: SushiV2Factory. 
	**/
	IUniswapV2Factory internal constant factory =
		IUniswapV2Factory(0xc35DADB65012eC5796536bD9864eD8773aBc74C4);

	/** 
		@dev Address of Wrapped Matic.
	**/
	IWETH internal constant wmatic =
		IWETH(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);

	/** 
		@dev All the events for the router of SushiSwap:
		addLiquidity, removeLiquidity and swap.
	**/

	event LogSwap(address indexed src, address indexed dest, uint256 amount);
	event LogLiquidityAdd(
		address indexed tokenA,
		address indexed tokenB,
		uint256 amountA,
		uint256 amountB
	);
	event LogLiquidityRemove(
		address indexed tokenA,
		address indexed tokenB,
		uint256 amountA,
		uint256 amountB
	);

	/**
	  @dev Add liquidity to Sushiswap pools.
	  @param amountA Amount of tokenA to addLiquidity.
	  @param amountB Amount of tokenB to addLiquidity.
	  @param getId Read the value of the amount of the token from memory contract position 1.
	  @param getId2 Read the value of the amount of the token from memory contract position 2.
	  @param setId Set value of the LP tokens received in the memory contract.
		@param divider (for now is always 1).
	**/
	function addLiquidity(
		IERC20 tokenA,
		IERC20 tokenB,
		uint256 amountA,
		uint256 amountB,
		uint256 getId,
		uint256 getId2,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 realAmtA = getId > 0 ? getUint(getId).div(divider) : amountA;
		uint256 realAmtB = getId2 > 0 ? getUint(getId2).div(divider) : amountB;

		require(
			realAmtA > 0 && realAmtB > 0,
			"AddLiquidity: INCORRECT_AMOUNTS"
		);

		IERC20 tokenAReal = tokenA.isETH() ? wmatic : tokenA;
		IERC20 tokenBReal = tokenB.isETH() ? wmatic : tokenB;

		/**
      @dev If either the tokenA or tokenB is WMATIC wrap it.
    **/
		if (tokenA.isETH()) {
			wmatic.deposit{value: realAmtA}();
		}
		if (tokenB.isETH()) {
			wmatic.deposit{value: realAmtB}();
		}

		/**
      @dev Approve the router to spend the tokenA and the tokenB.
    **/
		tokenAReal.universalApprove(address(router), realAmtA);
		tokenBReal.universalApprove(address(router), realAmtB);

		(, , uint256 liquidity) = router.addLiquidity(
			address(tokenAReal),
			address(tokenBReal),
			realAmtA,
			realAmtB,
			1,
			1,
			address(this),
			block.timestamp + 1
		);

		if (setId > 0) {
			setUint(setId, liquidity);
		}

		emit LogLiquidityAdd(
			address(tokenAReal),
			address(tokenBReal),
			amountA,
			amountB
		);
	}

	/**
	  @dev Remove liquidity from the Sushiswap pool.
	  @param tokenA Address of token A from the pool.
	  @param tokenA Address of token B from the pool.
	  @param amountPoolTokens Amount of the LP tokens to burn. 
	  @param getId Read the value from the memory contract. 
	  @param setId Set value of the amount of the tokenA received in memory contract position 1.
	  @param setId2 Set value of the amount of the tokenB in memory contract position 2.
		@param divider (for now is always 1).
	**/
	function removeLiquidity(
		IERC20 tokenA,
		IERC20 tokenB,
		uint256 amountPoolTokens,
		uint256 getId,
		uint256 setId,
		uint256 setId2,
		uint256 divider
	) external payable {
		uint256 realAmt = getId > 0
			? getUint(getId).div(divider)
			: amountPoolTokens;

		IERC20 tokenAReal = tokenA.isETH() ? wmatic : tokenA;
		IERC20 tokenBReal = tokenB.isETH() ? wmatic : tokenB;

		/** 
      @dev Get the address of the pairPool for the two address of the tokens.
    **/
		address poolToken = address(factory.getPair(tokenA, tokenB));

		/**
      @dev Approve the router to spend our LP tokens. 
    **/
		IERC20(poolToken).universalApprove(address(router), realAmt);

		(uint256 amountA, uint256 amountB) = router.removeLiquidity(
			address(tokenAReal),
			address(tokenBReal),
			realAmt,
			1,
			1,
			address(this),
			block.timestamp + 1
		);

		/**
      @dev Set the tokenA received in the memory contract.
    **/
		if (setId > 0) {
			setUint(setId, amountA);
		}

		/**
      @dev Set the tokenB received in the memory contract.
    **/
		if (setId2 > 0) {
			setUint(setId2, amountB);
		}

		emit LogLiquidityRemove(
			address(tokenAReal),
			address(tokenBReal),
			amountA,
			amountB
		);
	}

	/**
	  @dev Swap tokens in SushiSwap Dex with the SushiSwap: SushiV2Router02.
	  @param path Path where the route go from the fromToken to the destToken.
	  @param amountOfTokens Amount of tokens to be swapped, fromToken => destToken.
	  @param getId Read the value of tokenAmt from memory contract, if is needed.
	  @param setId Set value of the tokens swapped in memory contract, if is needed.
		@param divider (for now is always 1).
	**/
	function swap(
		address[] memory path,
		uint256 amountOfTokens,
		uint256 getId,
		uint256 setId,
		uint256 divider
	) external payable {
		uint256 memoryAmount = getId > 0
			? getUint(getId).div(divider)
			: amountOfTokens;
		require(memoryAmount > 0, "SwapTokens: ZERO_AMOUNT");
		require(path.length >= 2, "SwapTokens: INVALID_PATH");

		/**
			@dev The two tokens, to swap, the path[0] and the path[1].
		**/
		IERC20 fromToken = IERC20(path[0]);
		IERC20 destToken = IERC20(path[path.length - 1]);

		/**
			@dev If the token is the WMATIC then we should first deposit,
			if not then we should only use the universalApprove to approve
			the router to spend the tokens. 
		**/
		if (fromToken.isETH()) {
			wmatic.deposit{value: memoryAmount}();
			wmatic.universalApprove(address(router), memoryAmount);
			path[0] = address(wmatic);
		} else {
			fromToken.universalApprove(address(router), memoryAmount);
		}

		if (destToken.isETH()) {
			path[path.length - 1] = address(wmatic);
		}

		require(path[0] != path[path.length - 1], "SwapTokens: SAME_ASSETS");

		uint256 received = router.swapExactTokensForTokens(
			memoryAmount,
			1,
			path,
			address(this),
			block.timestamp + 1
		)[path.length - 1];

		if (destToken.isETH()) {
			wmatic.withdraw(received);
		}

		if (setId > 0) {
			setUint(setId, received);
		}

		emit LogSwap(address(fromToken), address(destToken), memoryAmount);
	}
}

contract SushiswapLogic is SushiswapResolver {
	/** 
    @dev The fallback function is going to handle
    the Matic sended without any call.
  **/
	receive() external payable {}
}
