const {
  deployments: { fixture, get },
  artifacts,
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  WMATIC,
  WETH,
  DAI,
  USDC,
  crMATIC,
  crDAI,
  crUSDC,
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");

contract("Cream Logic", () => {
  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry"]);

    cream = await get("CreamLogic");
    quick = await get("QuickswapLogic");
    _cream = new web3.eth.Contract(cream.abi, cream.address);
    _quick = new web3.eth.Contract(quick.abi, quick.address);

    // TOKENS
    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);
    crMatic = await IERC20.at(crMATIC);
    crDai = await IERC20.at(crDAI);
    crUsdc = await IERC20.at(crUSDC);

    registry = await ethers.getContract("EthaRegistry");
    memory = await ethers.getContract("Memory");
    investments = await ethers.getContract("Investments");
    feeManager = await ethers.getContract("FeeManager");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should deposit MATIC to Cream", async function () {
    const data = await _cream.methods
      .mintCToken(MATIC, toWei(100), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([cream.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
      value: toWei(100),
    });

    expectEvent(tx, "LogMint", {
      erc20: MATIC,
      tokenAmt: toWei(100),
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await crMatic.balanceOf(wallet.address);
    console.log("\tcrMatic tokens received:", balance * 1e-8);
    expect(balance * 1e-8).to.be.greaterThan(0);

    // Using investments adapter
    const balances = await investments.getBalances([MATIC], wallet.address);
    console.log("\tMatic invested:", fromWei(balances[0].cream));
    expect(fromWei(balances[0].cream)).to.be.greaterThan(0);
  });

  it("should deposit DAI to Cream starting with Matic", async function () {
    const data1 = await _quick.methods
      .swap([MATIC, DAI], toWei(100), 0, 1, 1)
      .encodeABI();

    const data2 = await _cream.methods
      .mintCToken(DAI, 0, 1, 0, 1) // amount handled by stored memory value
      .encodeABI();

    const tx = await wallet.execute(
      [quick.address, cream.address],
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

    const balance = await crDai.balanceOf(wallet.address);
    console.log("\tcrDAI received:", balance * 1e-8);
    expect(balance * 1e-8).to.be.greaterThan(0);
  });

  it("should redeem DAI from Cream", async function () {
    // Using investments adapter
    const balances = await investments.getBalances([DAI], wallet.address);
    daiToRedeem = balances[0].cream;

    console.log("\tDAI invested:", fromWei(daiToRedeem));
    expect(fromWei(daiToRedeem)).to.be.greaterThan(0);

    const data = await _cream.methods
      .redeemUnderlying(DAI, toBN(daiToRedeem), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([cream.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogRedeem", {
      erc20: DAI,
      tokenAmt: toBN(daiToRedeem),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await crDai.balanceOf(wallet.address);
    console.log("\tcrDAI balance:", balance * 1e-8);
    expect(fromWei(balance) < 0.1); // there is some dust for the interest earned
  });

  it("should collect fees when redeeming", async function () {
    const fee = await feeManager.getLendingFee(DAI);

    const balance = await dai.balanceOf(owner);
    console.log("\tDAI received:", fromWei(balance));
    expect(fromWei(balance)).to.be.equal(
      (fromWei(daiToRedeem) * Number(fee)) / 10000
    );
  });

  it("should borrow ETH from Cream", async function () {
    const data = await _cream.methods
      .borrow(WETH, toWei(0.001), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([cream.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogBorrow", {
      erc20: WETH,
      tokenAmt: toWei(0.001),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await eth.balanceOf(wallet.address);
    expect(fromWei(balance) > 0);
  });

  it("should repayed borrowed ETH to Cream", async function () {
    const data = await _cream.methods
      .repay(WETH, toWei(0.0005), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([cream.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogPayback", {
      erc20: WETH,
      tokenAmt: toWei(0.0005),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await eth.balanceOf(wallet.address);
    expect(fromWei(balance)).to.be.greaterThan(0);
  });
});
