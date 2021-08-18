const { task } = require("hardhat/config");

task(
  "logic:check",
  "Check status of logic contract",
  async ({ logic }, { ethers }) => {
    const registry = await ethers.getContract("EthaRegistry");
    const isEnabled = await registry.logicProxies(logic);
    console.log(`Logic ${logic} is ${isEnabled ? "ENABLED" : "NOT ENABLED"}!`);
  }
).addParam("logic", "logic contract address");

task(
  "logic:enable",
  "Disable logic contract",
  async ({ logic }, { ethers }) => {
    const registry = await ethers.getContract("EthaRegistry");
    await registry.enableLogic(logic);
    console.log(`Logic ${logic} is enabled!`);
  }
).addParam("logic", "logic contract address");

task(
  "logic:disable",
  "Disable logic contract",
  async ({ logic }, { ethers }) => {
    const registry = await ethers.getContract("EthaRegistry");
    await registry.disableLogic(logic);
    console.log(`Logic ${logic} is disabled!`);
  }
).addParam("logic", "logic contract address");
