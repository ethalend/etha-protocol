const {
  deployments: { fixture, get },
  artifacts,
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IStrat2 = artifacts.require("IStrat2");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  DAI,
  USDC,
  USDT,
  LINK,
  WMATIC,
  MUSD,
  IMUSD,
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");

const FEE = 1000;

contract("mStable Vault", () => {
  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 18000000,
          },
        },
      ],
    });

    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["EthaRegistry", "MStableDist"]);

    mstable = await get("MStableLogic");
    quick = await get("QuickswapLogic");
    vault = await get("VaultLogic");
    _mstable = new web3.eth.Contract(mstable.abi, mstable.address);
    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);

    // TOKENS
    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    usdt = await IERC20.at(USDT);
    link = await IERC20.at(LINK);
    wmatic = await IERC20.at(WMATIC);
    musd = await IERC20.at(MUSD);
    imusd = await IERC20.at(IMUSD);

    registry = await ethers.getContract("EthaRegistry");
    mstableVault = await ethers.getContract("MStableVault");
    strat = await ethers.getContract("MStableStrat");
    harvester = await ethers.getContract("Harvester");
    etha = await ethers.getContract("ETHAToken");
    factory = await ethers.getContract("VaultDistributionFactory");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should set vault fee", async function () {
    await mstableVault.changePerformanceFee(FEE);
  });

  it("should initialize distribution contracts", async function () {
    await ethers.provider.send("evm_increaseTime", [10]); // add 10 seconds
    await ethers.provider.send("evm_mine"); // mine the nex

    await etha.mint(factory.address, toWei(process.env.REWARD_AMOUNT_VAULTS));

    await factory.notifyRewardAmounts();

    let { stakingRewards } = await factory.stakingRewardsInfoByStakingToken(
      IMUSD
    );

    const balance = await etha.balanceOf(stakingRewards);
    expect(String(balance)).to.be.equal(
      toWei(process.env.REWARD_AMOUNT_VAULTS)
    );
  });

  it("should get DAI using quickswap", async function () {
    const amount = toWei(100);

    const data = await _quick.methods
      .swap([MATIC, DAI], amount, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await dai.balanceOf(wallet.address);
    console.log("\tDAI received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should swap DAI to USDC on mUSD pool", async function () {
    const amountDAI = toWei(20);
    const data = await _mstable.methods
      .swap(DAI, USDC, amountDAI, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([mstable.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogSwap", {
      src: DAI,
      dest: USDC,
      amount: amountDAI,
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await usdc.balanceOf(wallet.address);
    console.log("\tUSDC received:", balance * 1e-6);
    expect(balance * 1e-6).to.be.greaterThan(0);
  });

  it("should add DAI liquidity to mUSD pool", async function () {
    const amountDAI = toWei(10);
    const data = await _mstable.methods
      .addLiquidity(DAI, amountDAI, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([mstable.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityAdd", {
      tokenA: DAI,
      amountA: amountDAI,
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await musd.balanceOf(wallet.address);
    console.log("\tmUSD received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should remove liquidity from mUSD pool as USDT", async function () {
    const amountMUSD = toWei(5);
    const data = await _mstable.methods
      .removeLiquidity(USDT, amountMUSD, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([mstable.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityRemove", {
      tokenA: USDT,
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await musd.balanceOf(wallet.address);
    console.log("\tmUSD left:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);

    const balance2 = await usdt.balanceOf(wallet.address);
    console.log("\tUSDT received:", balance2 * 1e-6);
    expect(balance2 * 1e-6).to.be.greaterThan(0);
  });

  it("should save mUSD to get imUSD", async function () {
    // LP Token balance
    const lpBalance = await musd.balanceOf(wallet.address);

    const data = await _mstable.methods.save(lpBalance, 0, 1).encodeABI();

    const tx = await wallet.execute([mstable.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
    });
    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await imusd.balanceOf(wallet.address);
    console.log("\timUSD received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should deposit imUSD into ETHA mstable vault", async function () {
    // imUSD Token balance
    const lpBalance = await imusd.balanceOf(wallet.address);

    const data = await _vault.methods
      .deposit(mstableVault.address, lpBalance, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await imusd.balanceOf(wallet.address);
    console.log("\timUSD left:", fromWei(balance));
    expect(fromWei(balance)).to.be.equal(0);

    const balance2 = await mstableVault.balanceOf(wallet.address);
    console.log("\tVault Tokens received:", fromWei(balance2));
    expect(fromWei(balance2)).to.be.greaterThan(0);
  });

  it("Should have profits in ETHA vault", async function () {
    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 15]); // add 15 days
    await ethers.provider.send("evm_mine"); // mine the next block

    const strat2 = await IStrat2.at(strat.address);
    const totalYield = await strat2.totalYield();
    console.log("\tAvailable Matic Profits", fromWei(totalYield));

    expect(fromWei(totalYield)).to.be.greaterThan(0);
  });

  it("Should harvest profits in ETHA Vault", async function () {
    await harvester.harvestVault(mstableVault.address);

    const balance = await wmatic.balanceOf(owner);
    console.log("\tOwner WMATIC Fees Collected", fromWei(balance));
  });

  it("Should collect dividends from ETHA Vault", async function () {
    const dividends = await mstableVault.dividendOf(wallet.address);
    console.log("\tUser available LINK dividends", fromWei(dividends));
    expect(fromWei(dividends)).to.be.greaterThan(0);

    const data = await _vault.methods
      .claim(mstableVault.address, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await link.balanceOf(wallet.address);
    console.log("\tUser claimed LINK rewards", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);

    const balanceETHA = await etha.balanceOf(wallet.address);
    console.log("\tUser claimed ETHA rewards", fromWei(balanceETHA));
    expect(fromWei(balanceETHA)).to.be.greaterThan(0);
  });

  it("should redeem imUSD from ETHA mstable vault", async function () {
    // Vault Token balance
    const vaultBalance = await mstableVault.balanceOf(wallet.address);

    const data = await _vault.methods
      .withdraw(mstableVault.address, toBN(vaultBalance), 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await imusd.balanceOf(wallet.address);
    console.log("\timUSD balance:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);

    const balance2 = await mstableVault.balanceOf(wallet.address);
    expect(fromWei(balance2)).to.be.equal(0);
  });
});
