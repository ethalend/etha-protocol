// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/**
 * @title Mock ETHA token
 */
contract ETHAToken is ERC20PresetMinterPauser {
	constructor() ERC20PresetMinterPauser("Test ETHA", "TEST") {}
}
