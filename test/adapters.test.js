const {
  deployments: { fixture },
  ethers,
} = require("hardhat");

const { WMATIC, fromWei } = require("../deploy/utils");

contract("Adapters", ([]) => {
  let protocolsData, vaultAdapter;

  before(async function () {
    await fixture(["Adapters"]);

    protocolsData = await ethers.getContract("ProtocolsData");
    vaultAdapter = await ethers.getContract("VaultAdapter");
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

  it("should fetch vault info", async function () {
    const {
      depositToken,
      rewardsToken,
      strategy,
      distribution,
      totalDeposits,
      totalDepositsUSD,
      ethaRewardsRate,
    } = await vaultAdapter.getVaultInfo(
      "0xb56AAb9696B95a75A6edD5435bc9dCC4b07403b0",
      true
    );

    console.log("depositToken", depositToken);
    console.log("rewardsToken", rewardsToken);
    console.log("strategy", strategy);
    console.log("distribution", distribution);
    console.log("totalDeposits", String(totalDeposits));
    console.log("totalDepositsUSD", String(totalDepositsUSD));
    console.log("ethaRewardsRate", String(ethaRewardsRate));
  });
});
