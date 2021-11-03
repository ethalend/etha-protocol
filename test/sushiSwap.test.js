const {
  deployments: { fixture, get },
  artifacts,
  expect,
} = require("hardhat");

const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);
const IUniswapV2Factory = artifacts.require("IUniswapV2Factory");

const { expectEvent } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  WMATIC,
  WETH,
  WBTC,
  DAI,
  USDC,
  SUSHI_FACTORY,
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

contract("[SushiSwap Logic]", () => {
  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 17900000,
          },
        },
      ],
    });

    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "QuickDist"]);

    sushi = await get("SushiswapLogic");
    memoryLogic = await get("MemoryLogic");

    _sushi = new web3.eth.Contract(sushi.abi, sushi.address);
    _memory = new web3.eth.Contract(memoryLogic.abi, memoryLogic.address);

    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);
    wbtc = await IERC20.at(WBTC);
    factory = await IUniswapV2Factory.at(SUSHI_FACTORY);

    registry = await ethers.getContract("EthaRegistry");
    memory = await ethers.getContract("Memory");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\t[Smart Wallet Address]: ${swAddress}`);
  });

  it("[Should swap MATIC for DAI]", async function () {
    const amount = toWei(200);

    const data = await _sushi.methods
      .swap([MATIC, DAI], amount, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: DAI,
      amount: amount,
    });

    const balance = await dai.balanceOf(wallet.address);
    console.log("\t[DAI received]:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("[Should swap MATIC for USDC]", async function () {
    const amount = toWei(200);

    const data = await _sushi.methods
      .swap([MATIC, USDC], amount, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: amount,
    });

    expectEvent(tx, "LogSwap", {
      src: MATIC,
      dest: USDC,
      amount: amount,
    });

    const balance = await usdc.balanceOf(wallet.address);
    console.log("\t[USDC received]:", balance * 1e-6);
    expect(balance * 1e-6).to.be.greaterThan(0);
  });

  it("[Should provide liquidity with MATIC and DAI]", async function () {
    const maticBalance = toWei(140);
    const daiBalance = await dai.balanceOf(wallet.address);

    const data = await _sushi.methods
      .addLiquidity(MATIC, DAI, maticBalance, daiBalance, 0, 0, 1, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
      value: maticBalance,
    });

    expectEvent(tx, "LogLiquidityAdd", {
      tokenA: WMATIC,
      tokenB: DAI,
    });

    const poolAddress = await factory.getPair(WMATIC, DAI);
    const pool = await IERC20.at(poolAddress);
    const balance = await pool.balanceOf(wallet.address);
    console.log("\t[LP tokens received from WMATIC-DAI]:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("[Should provide liquidity with USDC and DAI]", async function () {
    const usdcBalance = await usdc.balanceOf(wallet.address);
    const daiBalance = await dai.balanceOf(wallet.address);

    const data = await _sushi.methods
      .addLiquidity(USDC, DAI, usdcBalance, daiBalance, 0, 0, 1, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityAdd", {
      tokenA: USDC,
      tokenB: DAI,
    });

    const poolAddress = await factory.getPair(USDC, DAI);
    const pool = await IERC20.at(poolAddress);
    const balance = await pool.balanceOf(wallet.address);
    console.log("\t[LP tokens received from USDC-DAI]:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });

  it("[Should remove liquidity from the MATIC and DAI]", async function () {
    const poolAddress = await factory.getPair(WMATIC, DAI);
    const pool = await IERC20.at(poolAddress);
    const poolBalance = await pool.balanceOf(wallet.address);

    const data = await _sushi.methods
      .removeLiquidity(WMATIC, DAI, poolBalance, 0, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityRemove", {
      tokenA: WMATIC,
      tokenB: DAI,
    });

    const daiBalance = await dai.balanceOf(wallet.address);
    console.log("\t[DAI balance]: ", fromWei(daiBalance));
  });

  it("[Should remove liquidity from the USDC and DAI]", async function () {
    const poolAddress = await factory.getPair(USDC, DAI);
    const pool = await IERC20.at(poolAddress);
    const poolBalance = await pool.balanceOf(wallet.address);

    const data = await _sushi.methods
      .removeLiquidity(USDC, DAI, poolBalance, 0, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([sushi.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogLiquidityRemove", {
      tokenA: USDC,
      tokenB: DAI,
    });

    const daiBalance = await dai.balanceOf(wallet.address);
    console.log("\t[DAI balance]: ", fromWei(daiBalance));
  });
});
