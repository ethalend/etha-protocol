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
  toWei,
  fromWei,
  toBN,
} = require("../deploy/utils");

contract("Balancer Logic", () => {
  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
          },
        },
      ],
    });

    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry"]);

    balancer = await get("BalancerLogic");
    wrap = await get("WrapLogic");
    _balancer = new web3.eth.Contract(balancer.abi, balancer.address);
    _wrap = new web3.eth.Contract(wrap.abi, wrap.address);

    // TOKENS
    dai = await IERC20.at(DAI);
    usdc = await IERC20.at(USDC);
    wmatic = await IERC20.at(WMATIC);
    eth = await IERC20.at(WETH);

    registry = await ethers.getContract("EthaRegistry");

    await registry.connect(_user).deployWallet();
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should swap MATIC to USDC", async function () {
    const poolId =
      "0x0297e37f1873d2dab4487aa67cd56b58e2f27875000100000000000000000002";

    const data1 = await _wrap.methods.wrap(toWei(100)).encodeABI();

    const data2 = await _balancer.methods
      .swap(poolId, WMATIC, USDC, toWei(100), 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute(
      [wrap.address, balancer.address],
      [data1, data2],
      {
        from: user,
        gasLimit: web3.utils.toHex(5e6),
        value: toWei(100),
      }
    );

    expectEvent(tx, "LogSwap", {
      src: WMATIC,
      dest: USDC,
      amount: toWei(100),
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    usdcBal = await usdc.balanceOf(wallet.address);
    console.log("\tUSDC tokens received:", usdcBal * 1e-6);
    expect(usdcBal * 1e-6).to.be.greaterThan(0);
  });

  it("should swap USDC to DAI", async function () {
    const poolId =
      "0x06df3b2bbb68adc8b0e302443692037ed9f91b42000000000000000000000012";

    const data = await _balancer.methods
      .swap(poolId, USDC, DAI, usdcBal, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([balancer.address], [data], {
      from: user,
      gasLimit: web3.utils.toHex(5e6),
    });

    expectEvent(tx, "LogSwap", {
      src: USDC,
      dest: DAI,
      amount: usdcBal,
    });

    console.log("\n\tGas Used:", tx.receipt.gasUsed);

    const balance = await dai.balanceOf(wallet.address);
    console.log("\tDAI tokens received:", fromWei(balance));
    expect(fromWei(balance)).to.be.greaterThan(0);
  });
});
