const {
  deployments: { fixture, get },
  ethers,
} = require("hardhat");

const { WMATIC, fromWei } = require("../deploy/utils");

const lpHolder = "0x9898f0688e71d738f7121334c9c15f8cd5a3fbca";

contract("Adapters", ([]) => {
  let protocolsData, vaultAdapter, vault;

  before(async function () {
    await fixture(["Adapters", "QuickDist"]);

    protocolsData = await ethers.getContract("ProtocolsData");
    vaultAdapter = await ethers.getContract("VaultAdapter");

    ({ address: vault } = await get("QuickVault"));
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
    const data = await vaultAdapter.getVaultInfo(vault);

    console.log(data);
  });

  it("should fetch quick lp data", async function () {
    // USDC/DAI LP

    const data = await vaultAdapter.getQuickswapBalance(
      "0xf04adBF75cDFc5eD26eeA4bbbb991DB002036Bdd",
      lpHolder
    );

    console.log(data);
  });
});
