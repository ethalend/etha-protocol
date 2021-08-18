const {
  deployments: { fixture },
  ethers,
} = require("hardhat");

const { WMATIC, fromWei, DAI, USDC, USDT } = require("../deploy/utils");

contract("Adapters", ([]) => {
  let protocolsData, vaultAdapter;

  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 18128690,
          },
        },
      ],
    });

    await fixture(["Adapters"]);

    protocolsData = await ethers.getContract("ProtocolsData");
    generalAdapter = await ethers.getContract("GeneralAdapter");
  });

  it("should show correct protocol data", async function () {
    const data = await protocolsData.getProtocolsData(WMATIC);

    console.log("\n\t\t===AAVE===");
    Object.keys(data.aave).map((t, i) => {
      if (i > 3) {
        if (t === "supplyRate" || t === "borrowRate")
          console.log("\t", t, fromWei(data.aave[t]) / 10 ** 9);
        else console.log("\t", t, fromWei(data.aave[t]));
      }
    });

    console.log("\n\t\t===CREAM===");
    Object.keys(data.cream).map((t, i) => {
      if (i > 3) {
        if (t === "supplyRate" || t === "borrowRate")
          console.log("\t", t, -1 + (1 + fromWei(data.cream[t])) ** 14805633);
        else console.log("\t", t, fromWei(data.cream[t]));
      }
    });
  });

  it("should fetch curve vault info", async function () {
    const {
      depositToken,
      rewardsToken,
      strategy,
      distribution,
      totalDeposits,
      totalDepositsUSD,
      ethaRewardsRate,
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
