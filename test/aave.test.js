const {
  deployments: { fixture, get },
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { expectEvent, expectRevert } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  WMATIC,
  WETH,
  DAI,
  USDC,
  amWMATIC,
  amDAI,
  amUSDC,
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");
const { expect } = require("chai");

contract("Aave Logic", () => {
  let registry, wallet, quick, aave, dai, eth, wmatic, memory, investments;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry"]);

    aave = await get("AaveLogic");
    quick = await get("QuickswapLogic");
    curve = await get("CurveLogic");
    memoryLogic = await get("MemoryLogic");
    vault = await get("VaultLogic");
    transfers = await get("TransferLogic");

    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _aave = new web3.eth.Contract(aave.abi, aave.address);
    _curve = new web3.eth.Contract(curve.abi, curve.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);
    _transfers = new web3.eth.Contract(transfers.abi, transfers.address);

    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);
    aMatic = await IERC20.at(amWMATIC);
    aDai = await IERC20.at(amDAI);
    aUsdc = await IERC20.at(amUSDC);

    registry = await ethers.getContract("EthaRegistry");
    investments = await ethers.getContract("Investments");
    memory = await ethers.getContract("Memory");
    feeManager = await ethers.getContract("FeeManager");

    await registry.connect(_user).deployWallet({ from: user });
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should deposit MATIC to Aave", async function () {
    const data = await _aave.methods
      .mintAToken(MATIC, toWei(100), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: toWei(100),
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    expectEvent(tx, "LogMint", {
      erc20: MATIC,
      tokenAmt: toWei(100),
    });

    const balance = await aMatic.balanceOf(wallet.address);
    console.log("\taMatic received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);

    // Using investments adapter
    const balances = await investments.getBalances(
      [MATIC, DAI],
      wallet.address
    );
    expect(fromWei(balances[0].aave)).to.be.greaterThan(0);
  });

  it("should deposit DAI to Aave starting with Matic", async function () {
    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(100), 0, 1, 1)
      .encodeABI();

    const data2 = await _aave.methods
      .mintAToken(DAI, 0, 1, 0, 1) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute(
      [quick.address, aave.address],
      [data1, data2],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
        value: toWei(100),
      }
    );

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: DAI,
      amount: toWei(100),
    });

    const stored = await memory.getUint(1);
    expect(fromWei(stored)).to.be.greaterThan(0);

    expectEvent(tx, "LogMint", {
      erc20: DAI,
      tokenAmt: toBN(stored),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await aDai.balanceOf(wallet.address);
    console.log("\taDAI received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should deposit USDC to Aave", async function () {
    // Get some USDC in the wallet
    let data = await _quick.methods
      .swap([MATIC, USDC], toWei(100), 0, 0, 1)
      .encodeABI();
    await wallet.execute([quick.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: toWei(100),
    });

    const usdcBalance = await usdc.balanceOf(wallet.address);
    console.log("\tUSDC to deposit:", usdcBalance / 10 ** 6);

    // Trigger Aave Deposit
    data = await _aave.methods
      .mintAToken(USDC, usdcBalance, 0, 0, 1) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    expectEvent(tx, "LogMint", {
      erc20: USDC,
      tokenAmt: usdcBalance,
    });

    const balance = await aUsdc.balanceOf(wallet.address);
    console.log("\taUSDC received:", balance / 10 ** 6);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should not be able to withdraw aUSDC tokens from wallet", async function () {
    const balance = await aUsdc.balanceOf(wallet.address);

    // Trigger Aave Deposit
    const data = await _transfers.methods
      .withdraw(amUSDC, balance) // amount handled by stored memory value
      .encodeABI();

    await expectRevert.unspecified(
      wallet.execute([transfers.address], [data], {
        from: user,
        gas: web3.utils.toHex(5e6),
      })
    );
  });

  it("should redeem DAI from Aave", async function () {
    daiToRedeem = await aDai.balanceOf(wallet.address);
    console.log("\tDAI to Redeem:", fromWei(daiToRedeem));

    const data = await _aave.methods
      .redeemAToken(DAI, daiToRedeem, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogRedeem", {
      erc20: DAI,
      tokenAmt: daiToRedeem,
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await aDai.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.lessThan(0.001); // there is some dust for the interest earned
  });

  it("should collect fees when redeeming", async function () {
    const fee = await feeManager.getLendingFee(DAI);
    const max = await feeManager.MAX_FEE();

    const balance = await dai.balanceOf(owner);
    console.log("\tDAI received:", fromWei(balance));
    expect((fromWei(daiToRedeem) * Number(fee)) / Number(max)).to.be.at.least(
      fromWei(balance)
    );
  });

  it("should borrow ETH from Aave", async function () {
    const data = await _aave.methods
      .borrow(WETH, toWei(0.001), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogBorrow", {
      erc20: WETH,
      tokenAmt: toWei(0.001),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await eth.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should repayed borrowed ETH to Aave", async function () {
    const data = await _aave.methods
      .repay(WETH, toWei(0.0005), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogPayback", {
      erc20: WETH,
      tokenAmt: toWei(0.0005),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await eth.balanceOf(wallet.address);
    assert(fromWei(balance) > 0);
  });
});
