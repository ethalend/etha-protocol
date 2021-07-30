const {
  deployments: { fixture, get },
  ethers,
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const {
  expectEvent,
  expectRevert,
  time,
} = require("@openzeppelin/test-helpers");

const {
  MATIC,
  WMATIC,
  WETH,
  DAI,
  USDC,
  amWMATIC,
  amDAI,
  amUSDC,
  amDAI_DEBT,
  toWei,
  fromWei,
  toBN,
  CURVE_POOL,
  AAVE_INCENTIVES,
} = require("../deploy/utils");
const { expect } = require("chai");

contract("Advanced Features", () => {
  let registry, wallet, quick, aave, dai, eth, wmatic, memory, investments;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "QuickStrat"]);

    aave = await get("AaveLogic");
    quick = await get("QuickswapLogic");
    curve = await get("CurveLogic");
    memoryLogic = await get("MemoryLogic");
    vault = await get("VaultLogic");
    transfers = await get("TransferLogic");
    claim = await get("ClaimLogic");

    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _aave = new web3.eth.Contract(aave.abi, aave.address);
    _curve = new web3.eth.Contract(curve.abi, curve.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);
    _transfers = new web3.eth.Contract(transfers.abi, transfers.address);
    _claim = new web3.eth.Contract(claim.abi, claim.address);

    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);
    aMatic = await IERC20.at(amWMATIC);
    aDai = await IERC20.at(amDAI);
    aUsdc = await IERC20.at(amUSDC);

    registry = await ethers.getContract("EthaRegistry");
    quickVault = await ethers.getContract("QuickVault");
    investments = await ethers.getContract("Investments");
    quickVault = await ethers.getContract("QuickVault");
    aaveIncentives = await ethers.getContractAt(
      "IAaveIncentives",
      AAVE_INCENTIVES
    );

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

  it("should borrow DAI from Aave and invest in Quick Vault", async function () {
    const amountDai = toWei(30);
    const data1 = await _aave.methods
      .borrow(DAI, amountDai, 0, 0, 1)
      .encodeABI();

    // Swap 50% DAI to USDC
    const data2 = await _curve.methods
      .swap(CURVE_POOL, DAI, USDC, toBN(amountDai).div(toBN(2)), 0, 1, 1) // store USDC received in memory contract pos 1
      .encodeABI();

    // Add liquidity to Quickswap
    const data3 = await _quick.methods
      .addLiquidity(DAI, USDC, toBN(amountDai).div(toBN(2)), 0, 0, 1, 1, 1) // store LP tokens received in memory
      .encodeABI();

    // Deposit to quick vault
    const data4 = await _vault.methods
      .deposit(quickVault.address, 0, 1)
      .encodeABI();

    const tx = await wallet.execute(
      [aave.address, curve.address, quick.address, vault.address],
      [data1, data2, data3, data4],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const vaultBalance = await quickVault.balanceOf(wallet.address);
    console.log("\tVault tokens received:", fromWei(vaultBalance));
    expect(fromWei(vaultBalance)).to.be.greaterThan(0);
  });

  it("should reinvest Aave Matic rewards into DAI Lending", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(7));

    let balance = await aDai.balanceOf(wallet.address);
    console.log("\tInitial aDai balance:", fromWei(balance));
    expect(fromWei(balance)).to.be.equal(0);

    const tokens = [amWMATIC, amDAI_DEBT];

    const rewardAmount = await aaveIncentives.getRewardsBalance(
      tokens,
      wallet.address
    );
    console.log("\tClaimable WMATIC:", fromWei(rewardAmount));

    const data1 = await _claim.methods
      .claimAaveRewards(tokens, toBN(rewardAmount))
      .encodeABI();

    const data2 = await _quick.methods
      .swap([WMATIC, DAI], toBN(rewardAmount), 0, 1, 1)
      .encodeABI();

    const data3 = await _aave.methods
      .mintAToken(DAI, 0, 1, 0, 1) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute(
      [claim.address, quick.address, aave.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    balance = await aDai.balanceOf(wallet.address);
    console.log("\taDai received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("should swap Aave collateral from MATIC to USDC", async function () {
    // Using investments adapter
    const balances = await investments.getBalances([MATIC], wallet.address);
    expect(fromWei(balances[0].aave)).to.be.greaterThan(0);

    let fee = await registry.getFee();
    fee = Number(fee) / 100000;

    const data1 = await _aave.methods
      .redeemAToken(WMATIC, toWei(5), 0, 0, 1)
      .encodeABI();

    const data2 = await _quick.methods
      .swap([WMATIC, USDC], toWei(5 * (1 - fee)), 0, 1, 1) // need to take care of redeem fee
      .encodeABI();

    const data3 = await _aave.methods
      .mintAToken(USDC, 0, 1, 0, 1) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute(
      [aave.address, quick.address, aave.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const usdInvested = await aUsdc.balanceOf(wallet.address);
    console.log("\tUSDC invested:", usdInvested * 1e-6);
    expect(usdInvested * 1e-6).to.be.greaterThan(0);
  });
});
