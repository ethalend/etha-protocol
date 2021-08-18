/**
 * @type import('hardhat/config').HardhatUserConfig
 */

require("dotenv").config();
require("@nomiclabs/hardhat-truffle5");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("chai");

require("./tasks/fees");
require("./tasks/logics");
require("./tasks/distribution");

if (!process.env.MAINNET_PRIVKEY)
  throw new Error("MAINNET_PRIVKEY missing from .env file");

if (!process.env.NODE_URL) throw new Error("NODE_URL missing from .env file");

if (!process.env.POLYGON_SCAN_KEY)
  throw new Error("POLYGON_SCAN_KEY missing from .env file");

module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: process.env.NODE_URL,
        blockNumber: 18053716,
        timeout: 300000,
      },
    },
    fork: {
      url: "http://localhost:8545",
      gasMultiplier: 2,
      timeout: 300000,
    },
    polygon: {
      url: process.env.NODE_URL,
      accounts: [process.env.MAINNET_PRIVKEY],
      gasMultiplier: 5,
      timeout: 300000,
    },
  },
  namedAccounts: {
    deployer: 0,
    registryOwner: 0,
    multisig: 0,
  },
  etherscan: {
    apiKey: process.env.POLYGON_SCAN_KEY,
  },
  solidity: {
    compilers: [
      {
        version: "0.5.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 240000,
  },
};
