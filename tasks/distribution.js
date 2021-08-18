const { task } = require("hardhat/config");

const {
  constants: { ZERO_ADDRESS },
} = require("@openzeppelin/test-helpers");

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
