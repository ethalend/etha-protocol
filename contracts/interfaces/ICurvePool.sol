// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// 0x445fe580ef8d70ff569ab36e80c647af338db351

interface ICurvePool {
	event TokenExchangeUnderlying(
		address indexed buyer,
		int128 sold_id,
		uint256 tokens_sold,
		int128 bought_id,
		uint256 tokens_bought
	);

	// solium-disable-next-line mixedcase
	function exchange_underlying(
		int128 i,
		int128 j,
		uint256 dx,
		uint256 minDy
	) external returns (uint256);

	function add_liquidity(
		uint256[3] calldata amounts,
		uint256 min_mint_amount,
		bool use_underlying
	) external returns (uint256);

	function remove_liquidity_imbalance(
		uint256[3] calldata amounts,
		uint256 max_burn_amount,
		bool use_underlying
	) external;

	function remove_liquidity_one_coin(
		uint256 token_amount,
		int128 i,
		uint256 min_amount,
		bool use_underlying
	) external returns (uint256);

	function calc_withdraw_one_coin(uint256 _token_amount, int128 i)
		external
		view
		returns (uint256);

	function calc_token_amount(uint256[3] calldata amounts, bool is_deposit)
		external
		view
		returns (uint256);

	function get_virtual_price() external view returns (uint256);

	function underlying_coins(uint256) external view returns (address);

	function lp_token() external view returns (address);
}
