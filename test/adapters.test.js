const {
  deployments: { fixture, get },
  ethers,
} = require("hardhat");

const { WMATIC, fromWei } = require("../deploy/utils");

contract("Adapters", ([]) => {
  let protocolsData, vaultAdapter, vault;

  before(async function () {
    await fixture(["Adapters", "QuickDist"]);

    protocolsData = await ethers.getContract("ProtocolsData");
    vaultAdapter = await ethers.getContract("VaultAdapter");

    ({ address: vault } = await get("QuickVault"));
  });

  it.skip("should show correct protocol data", async function () {
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
});
