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
  MUSD,
  toWei,
  fromWei,
} = require("../deploy/utils");

contract("mStable Logic", () => {
  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 17000000,
          },
        },
      ],
    });

    [_owner, _user] = await ethers.getSigners();
    user = _user.address;

    await fixture(["EthaRegistry", "MStableStrat"]);

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
    musd = await IERC20.at(MUSD);

    registry = await ethers.getContract("EthaRegistry");
    mstableVault = await ethers.getContract("MStableVault");
    strat = await ethers.getContract("MStableStrat");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
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

  it("should deposit MUSD into ETHA mstable vault", async function () {
    // LP Token balance
    const lpBalance = await musd.balanceOf(wallet.address);

    const data = await _vault.methods
      .deposit(mstableVault.address, lpBalance, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await musd.balanceOf(wallet.address);
    console.log("\tmUSD left:", fromWei(balance));
    expect(fromWei(balance)).to.be.equal(0);

    const balance2 = await mstableVault.balanceOf(wallet.address);
    console.log("\tVault Tokens received:", fromWei(balance2));
    expect(fromWei(balance2)).to.be.greaterThan(0);
  });

  it("should redeem MUSD from ETHA mstable vault", async function () {
    // await time.advanceBlock();
    // await time.increase(time.duration.days(7));

    await ethers.provider.send("evm_increaseTime", [60 * 60 * 24 * 7]); // add 7 days
    await ethers.provider.send("evm_mine"); // mine the nex

    const strat2 = await IStrat2.at(strat.address);
    const totalYield = await strat2.totalYield();
    console.log("\tAvailable Matic Profits", fromWei(totalYield));

    // Vault Token balance
    const vaultBalance = await mstableVault.balanceOf(wallet.address);

    const data = await _vault.methods
      .withdraw(mstableVault.address, vaultBalance, 0)
      .encodeABI();

    const tx = await wallet.execute([vault.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await musd.balanceOf(wallet.address);
    console.log("\tmUSD balance:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);

    const balance2 = await mstableVault.balanceOf(wallet.address);
    expect(fromWei(balance2)).to.be.equal(0);
  });
});
