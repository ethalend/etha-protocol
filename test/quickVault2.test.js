const {
  deployments: { fixture, get },
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const VaultLogic = artifacts.require("VaultLogic");
const IStrat2 = artifacts.require("IStrat2");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { time, expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  QUICK,
  WMATIC,
  WETH,
  WBTC,
  USDT,
  USDC,
  QUICK_LP2: QUICK_LP,
  CURVE_POOL,
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");

const WITHDRAWAL_FEE = 10; // 0.1%
const PERFORMANCE_FEE = 1700; // 17% performance

contract("Quick Vault 2", ([]) => {
  let registry,
    wallet,
    vault,
    _vault,
    quick,
    _quick,
    curve,
    _curve,
    usdt,
    usdc,
    wbtc,
    quickToken,
    quickLP,
    quickVault,
    strat,
    harvester;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "QuickDist2"]);

    cream = await get("CreamLogic");
    quick = await get("QuickswapLogic");
    curve = await get("CurveLogic");
    memoryLogic = await get("MemoryLogic");
    vault = await get("VaultLogic");

    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _curve = new web3.eth.Contract(curve.abi, curve.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);

    usdt = await IERC20.at(USDT);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);
    wbtc = await IERC20.at(WBTC);
    quickToken = await IERC20.at(QUICK);
    quickLP = await IERC20.at(QUICK_LP);

    registry = await ethers.getContract("EthaRegistry");
    memory = await ethers.getContract("Memory");
    investments = await ethers.getContract("Investments");
    balances = await ethers.getContract("Balances");
    etha = await ethers.getContract("ETHAToken");
    factory = await ethers.getContract("VaultDistributionFactory");
    quickVault = await ethers.getContract("QuickVault2");
    strat = await ethers.getContract("QuickStrat2");
    harvester = await ethers.getContract("Harvester");
    feeManager = await ethers.getContract("FeeManager");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should set vault fees", async function () {
    await feeManager.setVaultFee(quickVault.address, WITHDRAWAL_FEE);
    await quickVault.changePerformanceFee(PERFORMANCE_FEE);
  });

  it("should swap MATIC for USDT", async function () {
    const amount = toWei(100);

    const data = await _quick.methods
      .swap([MATIC, USDT], amount, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: USDT,
      amount: amount,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await usdt.balanceOf(wallet.address);
    console.log("\tUSDT received:", balance * 1e-6);
    expect(balance * 1e-6).to.be.greaterThan(0);
  });

  it("should swap MATIC for USDC", async function () {
    const amount = toWei(100);

    const data = await _quick.methods
      .swap([MATIC, USDC], amount, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: USDC,
      amount: amount,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await usdc.balanceOf(wallet.address);
    console.log("\tUSDC received:", balance * 1e-6);
    expect(balance * 1e-6).to.be.greaterThan(0);
  });

  it("should add liquidity to quick USDC-USDT pool", async function () {
    const usdtBal = await usdt.balanceOf(wallet.address);
    const usdcBal = await usdc.balanceOf(wallet.address);

    const data = await _quick.methods
      .addLiquidity(USDC, USDT, usdcBal, usdtBal, 0, 0, 1, 1)
      .encodeABI();

    const tx = await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityAdd", {
      tokenA: USDC,
      tokenB: USDT,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await quickLP.balanceOf(wallet.address);
    console.log("\tLP received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should initialize distribution contracts", async function () {
    await ethers.provider.send("evm_increaseTime", [10]); // add 10 seconds
    await ethers.provider.send("evm_mine"); // mine the next block

    await etha.mint(factory.address, toWei(process.env.REWARD_AMOUNT_VAULTS));

    await factory.notifyRewardAmounts();

    let { stakingRewards } = await factory.stakingRewardsInfoByStakingToken(
      QUICK_LP
    );

    const balance = await etha.balanceOf(stakingRewards);
    expect(String(balance)).to.be.equal(
      toWei(process.env.REWARD_AMOUNT_VAULTS)
    );
  });

  it("should deposit LP tokens to ETHA quick vault", async function () {
    _vault = new web3.eth.Contract(VaultLogic.abi, vault.address);

    // LP Token balance
    const lpBalance = await quickLP.balanceOf(wallet.address);

    const data = await _vault.methods
      .deposit(quickVault.address, lpBalance, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "VaultDeposit", {
      erc20: QUICK_LP,
      tokenAmt: lpBalance,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await quickVault.balanceOf(wallet.address);
    console.log("\tVault tokens received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should deposit LP tokens to ETHA quick vault starting with USDT only", async function () {
    // Getting some USDT in wallet
    const amount = toWei(100);
    const data = await _quick.methods
      .swap([MATIC, USDT], amount, 0, 0, 1)
      .encodeABI();
    await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    // Executing lego tx
    const initialBalance = await quickVault.balanceOf(wallet.address);
    const usdtBalance = await usdt.balanceOf(wallet.address);

    // Swap 50% USDT to USDC
    const data1 = await _curve.methods
      .swap(CURVE_POOL, USDT, USDC, toBN(usdtBalance).div(toBN(2)), 0, 1, 1) // store USDC received in memory contract pos 2
      .encodeABI();

    // Add liquidity to Quickswap
    const data2 = await _quick.methods
      .addLiquidity(USDT, USDC, toBN(usdtBalance).div(toBN(2)), 0, 0, 1, 1, 1) // store LP tokens received in memory
      .encodeABI();

    // Deposit to quick vault
    const data3 = await _vault.methods
      .deposit(quickVault.address, 0, 1)
      .encodeABI();

    const tx = await wallet.execute(
      [curve.address, quick.address, vault.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const stored = await memory.getUint(1);

    // EVENTS

    expectEvent(tx, "LogSwap", {
      src: USDT,
      dest: USDC,
      amount: toBN(usdtBalance).div(toBN(2)),
    });

    expectEvent(tx, "LogLiquidityAdd", {
      tokenA: USDT,
      tokenB: USDC,
    });

    expectEvent(tx, "VaultDeposit", {
      erc20: QUICK_LP,
      tokenAmt: toBN(stored),
    });

    const finalBalance = await quickVault.balanceOf(wallet.address);
    console.log(
      "\tVault tokens received:",
      fromWei(finalBalance) - fromWei(initialBalance)
    );
    expect(fromWei(finalBalance)).to.be.greaterThan(fromWei(initialBalance));
  });

  it("should be able to withdraw LP tokens from ETHA vault", async function () {
    const balance = await quickVault.balanceOf(wallet.address);

    const data = await _vault.methods
      .withdraw(quickVault.address, toBN(balance).div(toBN(3)), 0)
      .encodeABI();

    // Execute LEGO Tx
    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    // Lower ETHA Vault tokens
    const finalBalance = await quickVault.balanceOf(wallet.address);
    expect(fromWei(finalBalance) < fromWei(balance));
  });

  it("should be able to withdraw from ETHA vault as DAI", async function () {
    const balance = await quickVault.balanceOf(wallet.address);
    const initialUSDT = await usdt.balanceOf(wallet.address);

    // Build LEGO transaction

    // Withdraw from vault
    const data1 = await _vault.methods
      .withdraw(quickVault.address, toBN(balance).div(toBN(2)), 0)
      .encodeABI();

    // Remove liquidity from Quickswap
    const data2 = await _quick.methods
      .removeLiquidity(
        USDT,
        USDC,
        QUICK_LP,
        toBN(balance).div(toBN(2)),
        0,
        1,
        2,
        1
      )
      .encodeABI();

    // Swap USDC for DAI in curve
    const data3 = await _curve.methods
      .swap(CURVE_POOL, USDC, USDT, 0, 2, 0, 1) // getId:2
      .encodeABI();

    // Execute LEGO Tx
    const tx = await wallet.execute(
      [vault.address, quick.address, curve.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    // Lower ETHA Vault tokens
    const finalBalance = await quickVault.balanceOf(wallet.address);
    expect(fromWei(finalBalance) < fromWei(balance));

    // Greater DAI balance
    const finalUSDT = await usdt.balanceOf(wallet.address);
    console.log(
      `\tUSDT Received from burning ${fromWei(
        toBN(balance).div(toBN(2))
      )} Vault tokens: ${finalUSDT * 1e-6 - initialUSDT * 1e-6} USDT`
    );
    expect(finalUSDT * 1e-6 > initialUSDT * 1e-6).to.be.true;
  });

  it("Should have profits in ETHA vault", async function () {
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]); // add 7 days
    await ethers.provider.send("evm_mine"); // mine the nex

    const calcTotalValue = await strat.calcTotalValue();

    const strat2 = await IStrat2.at(strat.address);
    totalYield = await strat2.totalYield();
    console.log("\tAvailable Quick Profits", fromWei(totalYield));

    expect(fromWei(totalYield)).to.be.greaterThan(0);
    expect(fromWei(calcTotalValue)).to.be.greaterThan(0);
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await harvester.harvestVault(quickVault.address);

    const balance = await quickToken.balanceOf(owner);
    console.log("\tOwner QUICK Fees Collected", fromWei(balance));
    expect(fromWei(totalYield) * (PERFORMANCE_FEE / 10000)).to.be.at.least(
      fromWei(balance)
    );

    // From withdraw fees
    const balance2 = await quickLP.balanceOf(owner);
    console.log("\tLP collected:", fromWei(balance2));
    expect(fromWei(balance2)).to.be.greaterThan(0);
  });

  it("Should collect dividends from ETHA Vault", async function () {
    const dividends = await quickVault.dividendOf(wallet.address);
    console.log("\tUser available WMATIC dividends", fromWei(dividends));
    expect(fromWei(dividends)).to.be.greaterThan(0);

    const data = await _vault.methods.claim(quickVault.address, 0).encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    expectEvent(tx, "VaultClaim", {
      erc20: WMATIC,
    });

    expectEvent(tx, "Claim", {
      erc20: etha.address,
    });

    const balance = await wmatic.balanceOf(wallet.address);
    console.log("\tUser claimed WMATIC rewards", fromWei(balance));
    expect(fromWei(balance)).to.be.equal(fromWei(dividends));

    const balanceETHA = await etha.balanceOf(wallet.address);
    console.log("\tUser claimed ETHA rewards", fromWei(balanceETHA));
    expect(fromWei(balanceETHA)).to.be.greaterThan(0);
  });
});
