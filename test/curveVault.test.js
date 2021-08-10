const {
  deployments: { fixture, get },
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IStrat2 = artifacts.require("IStrat2");
const ICurveGauge = artifacts.require("ICurveGauge");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { time, expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  WMATIC,
  WETH,
  DAI,
  USDC,
  CRV,
  toWei,
  fromWei,
  toBN,
  A3CRV_ADDRESS,
  CURVE_POOL,
} = require("../deploy/utils");

const { expect } = require("chai");

contract("Curve Vault", () => {
  let registry,
    wallet,
    vault,
    quick,
    curve,
    dai,
    eth,
    wmatic,
    a3CRV,
    curveVault,
    strat,
    harvester,
    memory,
    etha,
    distRewards,
    factory;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "CurveDist"]);

    quick = await get("QuickswapLogic");
    curve = await get("CurveLogic");
    memoryLogic = await get("MemoryLogic");
    vault = await get("VaultLogic");

    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _curve = new web3.eth.Contract(curve.abi, curve.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);

    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    a3CRV = await IERC20.at(A3CRV_ADDRESS);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);

    registry = await ethers.getContract("EthaRegistry");
    memory = await ethers.getContract("Memory");
    investments = await ethers.getContract("Investments");
    balances = await ethers.getContract("Balances");
    etha = await ethers.getContract("ETHAToken");
    factory = await ethers.getContract("VaultDistributionFactory");
    curveVault = await ethers.getContract("CurveVault");
    strat = await ethers.getContract("CurveStrat");
    harvester = await ethers.getContract("Harvester");

    gauge = await ICurveGauge.at("0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should set vault fee", async function () {
    await curveVault.changePerformanceFee(1000);
  });

  it("should swap MATIC for DAI in quickswap", async function () {
    const data = await _quick.methods
      .swap([MATIC, DAI], toWei(100), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: toWei(100),
    });

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: DAI,
      amount: toWei(100),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await dai.balanceOf(wallet.address);
    console.log("DAI received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should add DAI liquidity to curve pool", async function () {
    const data = await _curve.methods
      .addLiquidity(CURVE_POOL, toWei(10), 0, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([curve.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await a3CRV.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should initialize distribution contracts", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(2));

    await etha.mint(factory.address, toWei(process.env.REWARD_AMOUNT_VAULTS));

    await factory.notifyRewardAmounts();

    let { stakingRewards } = await factory.stakingRewardsInfoByStakingToken(
      A3CRV_ADDRESS
    );

    const balance = await etha.balanceOf(stakingRewards);
    expect(String(balance)).to.be.equal(
      toWei(process.env.REWARD_AMOUNT_VAULTS)
    );
  });

  it("should deposit LP tokens to ETHA curve vault", async function () {
    // LP Token balance
    const lpBalance = await a3CRV.balanceOf(wallet.address);

    const data = await _vault.methods
      .deposit(curveVault.address, lpBalance, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await curveVault.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should deposit into ETHA vault starting with MATIC", async function () {
    // Build LEGO transaction
    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(50), 0, 1, 1)
      .encodeABI();

    // Add DAI liq
    const data2 = await _curve.methods
      .addLiquidity(CURVE_POOL, 0, 0, 1, 1, 1) // amount:0, tokenId:0, getId:1, setId:1, divider:1
      .encodeABI();

    const data3 = await _vault.methods
      .deposit(curveVault.address, 0, 1) // amount:0, getId:1
      .encodeABI();

    // Execute LEGO Tx
    const tx = await wallet.execute(
      [quick.address, curve.address, vault.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
        value: toWei(50),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    // Received ETHA Vault tokens
    const balance = await curveVault.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should be able to withdraw LP tokens from ETHA vault", async function () {
    const balance = await curveVault.balanceOf(wallet.address);

    const data = await _vault.methods
      .withdraw(curveVault.address, toBN(balance).div(toBN(3)), 0)
      .encodeABI();

    // Execute LEGO Tx
    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    // Lower ETHA Vault tokens
    const finalBalance = await curveVault.balanceOf(wallet.address);
    expect(fromWei(finalBalance)).to.be.lessThan(fromWei(balance));
  });

  it("should be able to withdraw from ETHA vault as DAI", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(1));

    const balance = await curveVault.balanceOf(wallet.address);
    const initialDAI = await dai.balanceOf(wallet.address);

    // Build LEGO transaction
    const data1 = await _vault.methods
      .withdraw(curveVault.address, toBN(balance).div(toBN(2)), 0)
      .encodeABI();

    const data2 = await _curve.methods
      .removeLiquidity(CURVE_POOL, toBN(balance).div(toBN(2)), 0, 0, 0, 1)
      .encodeABI();

    // Execute LEGO Tx
    const tx = await wallet.execute(
      [vault.address, curve.address],
      [data1, data2],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    expectEvent(tx, "Claim", {
      erc20: etha.address,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    // Lower ETHA Vault tokens
    const finalBalance = await curveVault.balanceOf(wallet.address);
    expect(fromWei(finalBalance) < fromWei(balance));

    // Greater DAI balance
    const finalDAI = await dai.balanceOf(wallet.address);
    expect(fromWei(finalDAI)).to.be.greaterThan(fromWei(initialDAI));
  });

  it("Should have profits in ETHA vault", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(7));

    const calcTotalValue = await strat.calcTotalValue();

    const strat2 = await IStrat2.at(strat.address);
    const totalYield = await strat2.totalYield();
    console.log("\tAvailable MATIC Profits", fromWei(totalYield));

    const totalYield2 = await strat2.totalYield2();
    console.log("\tAvailable CRV Profits", fromWei(totalYield2));

    expect(fromWei(totalYield)).to.be.greaterThan(0);
    expect(fromWei(calcTotalValue)).to.be.greaterThan(0);
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await harvester.harvestVault(curveVault.address);

    const balance = await wmatic.balanceOf(owner);
    console.log("\tOwner WMATIC Fees Collected", fromWei(balance));

    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("Should collect dividends from ETHA Vault", async function () {
    const dividends = await curveVault.dividendOf(wallet.address);
    console.log("\tUser available WETH dividends", fromWei(dividends));
    expect(fromWei(dividends)).to.be.greaterThan(0);

    const data = await _vault.methods.claim(curveVault.address, 0).encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "VaultClaim", {
      erc20: WETH,
    });

    expectEvent(tx, "Claim", {
      erc20: etha.address,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await eth.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);

    const balanceETHA = await etha.balanceOf(wallet.address);
    console.log("\tUser claimed ETHA rewards", fromWei(balanceETHA));
    expect(fromWei(balanceETHA)).to.be.greaterThan(0);
  });
});
