const {
  deployments: { fixture, get },
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  DAI,
  USDC,
  amDAI,
  crDAI,
  toWei,
  fromWei,
  toBN,
  CURVE_POOL,
  A3CRV_ADDRESS,
} = require("../deploy/utils");

contract("Chaining Transactions", () => {
  let registry,
    wallet,
    user,
    quick,
    aave,
    cream,
    curve,
    vault,
    memoryLogic,
    _quick,
    _aave,
    _cream,
    _memory,
    _curve,
    _vault,
    aaveDai,
    creamDai,
    memory,
    balances,
    curveVault,
    investments;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "CurveStrat"]);

    cream = await get("CreamLogic");
    aave = await get("AaveLogic");
    quick = await get("QuickswapLogic");
    curve = await get("CurveLogic");
    memoryLogic = await get("MemoryLogic");
    vault = await get("VaultLogic");
    curveVault = await get("CurveVault");
    _cream = new web3.eth.Contract(cream.abi, cream.address);
    _quick = new web3.eth.Contract(quick.abi, quick.address);
    _aave = new web3.eth.Contract(aave.abi, aave.address);
    _curve = new web3.eth.Contract(curve.abi, curve.address);
    _vault = new web3.eth.Contract(vault.abi, vault.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);

    aaveDai = await IERC20.at(amDAI);
    creamDai = await IERC20.at(crDAI);

    registry = await ethers.getContract("EthaRegistry");
    memory = await ethers.getContract("Memory");
    investments = await ethers.getContract("Investments");
    balances = await ethers.getContract("Balances");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should deposit DAI to Aave and Cream using Matic", async function () {
    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(100), 0, 1, 1)
      .encodeABI();

    const data2 = await _aave.methods
      .mintAToken(DAI, 0, 1, 0, 2) // amount handled by stored memory value
      .encodeABI();

    const data3 = await _cream.methods
      .mintCToken(DAI, 0, 1, 0, 2) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute(
      [quick.address, aave.address, cream.address],
      [data1, data2, data3],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
        value: toWei(100),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: DAI,
      amount: toWei(100),
    });

    const stored = await memory.getUint(1);
    expect(fromWei(stored)).to.be.greaterThan(0);

    expectEvent(tx, "LogMint", {
      erc20: DAI,
      tokenAmt: toBN(stored).div(toBN("2")),
    });

    const balances = await investments.getBalances([DAI], wallet.address);
    console.log("DAI supplied to Aave:", fromWei(balances[0].aave));
    console.log("DAI supplied to Cream:", fromWei(balances[0].cream));
    expect(fromWei(balances[0].aave)).to.be.greaterThan(0);
    expect(fromWei(balances[0].cream)).to.be.greaterThan(0);
  });

  it("should swap MATIC for DAI and USDC", async function () {
    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(100), 0, 0, 1)
      .encodeABI();

    const data2 = await _quick.methods
      .swap([MATIC, USDC], toWei(100), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute(
      [quick.address, quick.address],
      [data1, data2],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
        value: toWei(200),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const _balances = await balances.getBalances([DAI, USDC], wallet.address);
    console.log("DAI balance:", fromWei(_balances[0]));
    console.log("USDC balance:", _balances[1] / 10 ** 6);

    expect(fromWei(_balances[0])).to.be.greaterThan(0);
    expect(_balances[1] / 10 ** 6).to.be.greaterThan(0);
  });

  it("should invest in Curve Vault using MATIC and DAI balances", async function () {
    const _balances = await balances.getBalances([DAI], wallet.address);

    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(50), 0, 1, 1)
      .encodeABI();

    // Add stored value and initial value of dai balance
    const data2 = await _memory.methods
      .addValues([1], _balances[0])
      .encodeABI();

    const data3 = await _curve.methods
      .addLiquidity(CURVE_POOL, 0, 0, 1, 1, 1) // amount handled by stored memory value
      .encodeABI();

    const data4 = await _vault.methods
      .deposit(curveVault.address, 0, 1)
      .encodeABI();

    const tx = await wallet.execute(
      [quick.address, memoryLogic.address, curve.address, vault.address],
      [data1, data2, data3, data4],
      {
        from: user,
        gas: web3.utils.toHex(5e6),
        value: toWei(50),
      }
    );

    console.log("\tGas Used:", tx.receipt.gasUsed);

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: DAI,
      amount: toBN(toWei(50)),
    });

    const stored = await memory.getUint(1);
    expect(fromWei(stored)).to.be.greaterThan(0);

    expectEvent(tx, "VaultDeposit", {
      erc20: A3CRV_ADDRESS,
    });
  });
});
