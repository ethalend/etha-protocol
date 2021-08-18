const { task } = require("hardhat/config");

task(
  "lending:fee:get",
  "Get lending market withdrawal fee",
  async ({ asset }, { ethers }) => {
    const feeManager = await ethers.getContract("FeeManager");
    const max = await feeManager.MAX_FEE();
    const fee = await feeManager.getLendingFee(asset);

    console.log(`Asset ${asset} fee set to ${fee} (${(100 * fee) / max}%)`);
  }
).addParam("asset", "asset address");

task(
  "lending:fee:set",
  "Set vault withdrawal fee",
  async ({ fee, asset }, { ethers }) => {
    if (Number(fee) > 5000) throw new Error("High than 50%");
    const feeManager = await ethers.getContract("FeeManager");
    const max = await feeManager.MAX_FEE();
    await feeManager.setLendingFee(asset, fee);

    console.log(`Asset ${asset} fee set to ${fee}(${(100 * fee) / max}%)`);
  }
)
  .addParam("fee", "withdrawal fee (10000 = 100%)")
  .addParam("asset", "asset address");

task(
  "vault:fee:get",
  "Get vault withdrawal fee",
  async ({ vault }, { ethers }) => {
    const feeManager = await ethers.getContract("FeeManager");
    const max = await feeManager.MAX_FEE();
    const fee = await feeManager.getVaultFee(vault);

    console.log(`Vault ${vault} fee set to ${fee} (${(100 * fee) / max}%)`);
  }
).addParam("vault", "vault address");

task(
  "vault:fee:set",
  "Set vault withdrawal fee",
  async ({ fee, vault }, { ethers }) => {
    if (Number(fee) > 5000) throw new Error("High than 50%");
    const feeManager = await ethers.getContract("FeeManager");
    const max = await feeManager.MAX_FEE();
    await feeManager.setVaultFee(vault, fee);

    console.log(`Vault ${vault} fee set to ${fee}(${(100 * fee) / max}%)`);
  }
)
  .addParam("fee", "withdrawal fee (10000 = 100%)")
  .addParam("vault", "vault address");
