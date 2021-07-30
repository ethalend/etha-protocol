const { web3 } = require("hardhat");

// ERC20 Tokens
exports.MATIC = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
exports.WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
exports.WETH = "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619";
exports.DAI = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
exports.USDC = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174";
exports.USDT = "0xc2132D05D31c914a87C6611C10748AEb04B58e8F";
exports.QUICK = "0x831753DD7087CaC61aB5644b308642cc1c33Dc13";
exports.WBTC = "0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6";

// Aave Tokens
exports.amDAI = "0x27f8d03b3a2196956ed754badc28d73be8830a6e";
exports.amUSDC = "0x1a13f4ca1d028320a707d99520abfefca3998b7f";
exports.amUSDT = "0x60d55f02a771d515e077c9c2403a1ef324885cec";
exports.amWETH = "0x28424507fefb6f7f8e9d3860f56504e4e5f5f390";
exports.amWMATIC = "0x8df3aad3a84da6b69a4da8aec3ea40d9091b2ac4";

// Cream Tokens
exports.crDAI = "0x27f8d03b3a2196956ed754badc28d73be8830a6e";
exports.crUSDC = "0x1a13f4ca1d028320a707d99520abfefca3998b7f";
exports.crUSDT = "0x60d55f02a771d515e077c9c2403a1ef324885cec";
exports.crWETH = "0x28424507fefb6f7f8e9d3860f56504e4e5f5f390";
exports.crMATIC = "0x8df3aad3a84da6b69a4da8aec3ea40d9091b2ac4";

exports.A3CRV_ADDRESS = "0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171";
exports.QUICK_LP = "0xf04adBF75cDFc5eD26eeA4bbbb991DB002036Bdd"; // DAI-USDC
exports.CURVE_POOL = "0x445FE580eF8d70FF569aB36e80c647af338db351";

exports.toWei = (value) => web3.utils.toWei(String(value));
exports.fromWei = (value) => Number(web3.utils.fromWei(String(value)));
exports.toBN = (value) => new web3.utils.BN(String(value));
