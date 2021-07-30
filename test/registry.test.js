const {
  deployments: { fixture, get },
} = require("hardhat");

const Timelock = artifacts.require("Timelock");

const { time } = require("@openzeppelin/test-helpers");

// HELPERS

contract("Registry", ([owner, user, multisig]) => {
  let registry, quick, aave, timelock, memory, eta, user, _owner, _user;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    user = _user.address;

    await fixture(["Memory", "Logics", "SmartWallet"]);

    memory = await get("Memory");
    aave = await get("AaveLogic");
    quick = await get("QuickswapLogic");
    smartWalletImpl = await get("SmartWallet");

    registry = await ethers.getContract("EthaRegistry");

    const _timelock = await registry.timelock();
    timelock = await Timelock.at(_timelock);
  });

  it("should queue enabling logic contract", async function () {
    const signature = "enableLogicMultiple(address[])";

    const data = web3.eth.abi.encodeParameters(
      ["address[]"],
      [[quick.address]]
    );

    eta = Number(await time.latest()) + Number(time.duration.days(2));

    await timelock.queueTransaction(registry.address, 0, signature, data, eta);
  });

  it("should execute enabling logic contract", async function () {
    await time.increaseTo(eta);

    const signature = "enableLogicMultiple(address[])";

    const data = web3.eth.abi.encodeParameters(
      ["address[]"],
      [[quick.address]]
    );

    await timelock.executeTransaction(
      registry.address,
      0,
      signature,
      data,
      eta
    );
  });

  it("should execute enabling logic contracts", async function () {
    const quickEnabled = await registry.logicProxies(quick.address);
    const aaveEnabled = await registry.logicProxies(aave.address);

    assert(quickEnabled);
    assert(aaveEnabled);
  });
});
