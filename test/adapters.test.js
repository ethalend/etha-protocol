const { expect } = require("chai");
const {
  deployments: { fixture },
  ethers,
} = require("hardhat");

const {
  WMATIC,
  fromWei,
  DAI,
  USDC,
  USDT,
  QUICK_LP_STAKING,
  QUICK_LP2_STAKING,
} = require("../deploy/utils");

describe("Adapters", () => {
  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 20464262,
          },
        },
      ],
    });

    await fixture(["Adapters"]);

    protocolsData = await ethers.getContract("ProtocolsData");
    generalAdapter = await ethers.getContract("GeneralAdapter");
    feeManager = await ethers.getContract("FeeManager");
    dataAdapter = await ethers.getContract("DataAdapter");
    stakingAdapter = await ethers.getContract("StakingAdapter");
  });

  describe.skip("Protocols Adapter", () => {
    it("should show correct protocol data", async function () {
      const data = await protocolsData.getProtocolsData(WMATIC);

      console.log("\n\t\t===AAVE===");
      Object.keys(data.aave).map((t, i) => {
        if (i > 5) {
          if (t === "supplyRate" || t === "borrowRate")
            console.log("\t", t, fromWei(data.aave[t]) / 10 ** 9);
          else if (t === "ltv" || t === "threshold")
            console.log("\t", t, +data.aave[t] / 1000);
          else console.log("\t", t, fromWei(data.aave[t]));
        }
      });

      console.log("\n\t\t===CREAM===");
      Object.keys(data.cream).map((t, i) => {
        if (i > 5) {
          if (t === "supplyRate" || t === "borrowRate")
            console.log("\t", t, -1 + (1 + fromWei(data.cream[t])) ** 14805633);
          else console.log("\t", t, fromWei(data.cream[t]));
        }
      });
    });
  });

  describe.skip("General Adapter", () => {
    it("should fetch curve vault info", async function () {
      const {
        depositToken,
        rewardsToken,
        strategy,
        distribution,
        totalDeposits,
        totalDepositsUSD,
        ethaRewardsRate,
        performanceFee,
        withdrawalFee,
      } = await generalAdapter.getVaultInfo(
        "0x4e5b645B69e873295511C6cA5B8951c3ff4F74F4",
        0
      );

      console.log("depositToken", depositToken);
      console.log("rewardsToken", rewardsToken);
      console.log("strategy", strategy);
      console.log("distribution", distribution);
      console.log("totalDeposits", String(totalDeposits));
      console.log("totalDepositsUSD", String(totalDepositsUSD));
      console.log("ethaRewardsRate", String(ethaRewardsRate));
      console.log("performanceFee", String(performanceFee));
      console.log("withdrawalFee", String(withdrawalFee));
    });

    it("should fetch quick vault info", async function () {
      const {
        depositToken,
        rewardsToken,
        strategy,
        distribution,
        stakingContract,
        totalDeposits,
        totalDepositsUSD,
        ethaRewardsRate,
        performanceFee,
        withdrawalFee,
      } = await generalAdapter.getVaultInfo(
        "0xb56AAb9696B95a75A6edD5435bc9dCC4b07403b0",
        1
      );

      console.log("depositToken", depositToken);
      console.log("rewardsToken", rewardsToken);
      console.log("strategy", strategy);
      console.log("distribution", distribution);
      console.log("stakingContract", stakingContract);
      console.log("totalDeposits", String(totalDeposits));
      console.log("totalDepositsUSD", String(totalDepositsUSD));
      console.log("ethaRewardsRate", String(ethaRewardsRate));
      console.log("performanceFee", String(performanceFee));
      console.log("withdrawalFee", String(withdrawalFee));
    });

    it("should get DAI and USDC Matic incentives", async function () {
      const rewards = await generalAdapter.getAaveRewards([
        WMATIC,
        DAI,
        USDC,
        USDT,
      ]);
      console.log("rewards MATIC", fromWei(rewards[0]));
      console.log("rewards DAI", fromWei(rewards[1]));
      console.log("rewards USDC", fromWei(rewards[2]));
      console.log("rewards USDT", fromWei(rewards[3]));
    });
  });

  describe.skip("Data Adapter", () => {
    it("should return the reserve data from adapter of the WMatic in aave", async function () {
      const data = await dataAdapter.getDataForAssetAave(WMATIC);
      console.log("availableLiquidity: ", fromWei(data["availableLiquidity"]));
      console.log("totalVariableDebt: ", fromWei(data["totalVariableDebt"]));
      console.log("liquidityRate: ", fromWei(data["liquidityRate"]));
      console.log("variableBorrowRate: ", fromWei(data["variableBorrowRate"]));
      console.log("ltv: ", data["ltv"] / 1000);
      console.log("threshold: ", data["liquidationThreshold"] / 1000);
      assert(data);
    });

    it("should return the reserve data from adapter of the WMatic in cream", async function () {
      const data = await dataAdapter.getDataForAssetCream(WMATIC);
      console.log("availableLiquidity: ", fromWei(data["availableLiquidity"]));
      console.log("totalVariableDebt: ", fromWei(data["totalVariableDebt"]));
      console.log(
        "liquidityRate: ",
        -1 + (1 + fromWei(data["liquidityRate"])) ** 14805633
      );
      console.log(
        "variableBorrowRate: ",
        -1 + (1 + fromWei(data["variableBorrowRate"])) ** 14805633
      );
      console.log("ltv: ", data["ltv"] / 1000);
      console.log("threshold: ", data["liquidationThreshold"] / 1000);
      assert(data);
    });

    it("should return the asset data from adapter of the USDC in both protocols", async function () {
      const data = await dataAdapter.getDataAssetOfProtocols(
        "0x2791bca1f2de4661ed88a30c99a7a9449aa84174" // Data for USDC
      );
      console.log(data);
      assert(data);
    });

    it("should return the user data from adapter of the USDC in both protocols", async function () {
      const data = await dataAdapter.getDataUserOfProtocols(
        "0xb1bF53E17fA13cD7c0937eA9C8Ead91bd0a5b298"
      );
      console.log(data);
      assert(data);
    });
  });

  describe("Staking Adapter", () => {
    it("should return the reserve data from adapter of the WMatic in aave", async function () {
      const data = await stakingAdapter.getStakingInfo([
        QUICK_LP_STAKING,
        QUICK_LP2_STAKING,
      ]);

      data.map((t, i) => {
        console.log("\n\tStaking Token", t.stakingToken);
        console.log("\tRewards Token", t.rewardsToken);
        console.log("\tTotal Supply", String(t.totalSupply));
        console.log("\tReward Rate per Sec", String(t.rewardsRate));
      });

      expect(data.length).eq(2);
    });
  });
});
