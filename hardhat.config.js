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

const {
  constants: { ZERO_ADDRESS },
} = require("@openzeppelin/test-helpers");

if (!process.env.MAINNET_PRIVKEY)
  throw new Error("MAINNET_PRIVKEY missing from .env file");

if (!process.env.NODE_URL) throw new Error("NODE_URL missing from .env file");

if (!process.env.POLYGON_SCAN_KEY)
  throw new Error("POLYGON_SCAN_KEY missing from .env file");

task(
  "checkLogic",
  "Check status of logic contract",
  async ({ logic }, { ethers }) => {
    const registry = await ethers.getContract("EthaRegistry");
    const isEnabled = await registry.logicProxies(logic);
    console.log(`Logic ${logic} is ${isEnabled ? "ENABLED" : "NOT ENABLED"}!`);
  }
).addParam("logic", "logic contract address");

task(
  "dist:lend",
  "Get lending distribution contract for a token",
  async ({ token }, { ethers }) => {
    const registry = await ethers.getContract("EthaRegistry");
    const dist = await registry.distributionContract(token);

    if (dist === ZERO_ADDRESS)
      return console.log("distribution not set in Registry!");

    const factory = await ethers.getContract("LendingDistributionFactory");
    const { stakingRewards, rewardAmount, endTime } =
      await factory.stakingRewardsInfoByStakingToken(token);
    console.log(`Distribution contract deployed at ${stakingRewards}`);
    console.log(
      `Reward amount ${String(ethers.utils.formatEther(rewardAmount))} ETHA`
    );
    console.log(`End Time:  ${new Date(Number(endTime) * 1000)}`);
  }
).addParam("token", "token contract address");

task(
  "dist:vault",
  "Get vault distribution contract for a token",
  async ({ token }, { ethers }) => {
    const factory = await ethers.getContract("VaultDistributionFactory");
    const { stakingRewards, rewardAmount, endTime } =
      await factory.stakingRewardsInfoByStakingToken(token);
    console.log(`Distribution contract deployed at ${stakingRewards}`);
    console.log(
      `Reward amount ${String(ethers.utils.formatEther(rewardAmount))} ETHA`
    );
    console.log(`End Time:  ${new Date(Number(endTime) * 1000)}`);
  }
).addParam("token", "token contract address");

module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: process.env.NODE_URL,
        blockNumber: 16130000,
        timeout: 300000,
      },
    },
    fork: {
      url: "http://localhost:8545",
      gasMultiplier: 2,
      timeout: 300000,
    },
    mainnet: {
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
