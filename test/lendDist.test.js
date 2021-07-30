const {
  deployments: { fixture, get },
} = require("hardhat");

const LendingDistributionRewards = artifacts.require(
  "LendingDistributionRewards"
);
const IAaveIncentives = artifacts.require("IAaveIncentives");
const IWallet = artifacts.require("IWallet");
const IERC20 = artifacts.require(
  "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20"
);

const { time } = require("@openzeppelin/test-helpers");

const {
  MATIC,
  DAI,
  USDC,
  WMATIC,
  WETH,
  toWei,
  fromWei,
  amDAI,
  amUSDC,
  amWMATIC,
  AAVE_INCENTIVES,
} = require("../deploy/utils");

contract("Distribution", () => {
  let registry,
    distRewards,
    quick,
    aave,
    claim,
    factory,
    etha,
    aDai,
    owner,
    user;

  before(async function () {
    [_owner, _user] = await ethers.getSigners();
    owner = _owner.address;
    user = _user.address;

    await fixture(["Adapters", "EthaRegistry", "LendingDistributions"]);

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
    investments = await ethers.getContract("Investments");
    memory = await ethers.getContract("Memory");
    factory = await ethers.getContract("LendingDistributionFactory");
    etha = await ethers.getContract("ETHAToken");

    incentives = await IAaveIncentives.at(AAVE_INCENTIVES);

    await registry.connect(_user).deployWallet({ from: user });
    const swAddress = await registry.wallets(user);
    wallet = await IWallet.at(swAddress);

    console.log(`\nWallet Address: ${swAddress}`);
  });

  it("should initialize distribution contracts", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(1));

    await etha.mint(
      factory.address,
      toWei(+process.env.REWARD_AMOUNT_VAULTS * 4)
    );

    await factory.notifyRewardAmounts();

    let { stakingRewards } = await factory.stakingRewardsInfoByStakingToken(
      DAI
    );

    distRewards = await LendingDistributionRewards.at(stakingRewards);

    const balance = await etha.balanceOf(stakingRewards);
    expect(String(balance)).to.be.equal(
      toWei(process.env.REWARD_AMOUNT_VAULTS)
    );
  });

  it("should deposit DAI to Aave starting with Matic", async function () {
    const _aave = new web3.eth.Contract(aave.abi, aave.address);
    const _quick = new web3.eth.Contract(quick.abi, quick.address);

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

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await aDai.balanceOf(wallet.address);
    console.log("\taDAI received:", fromWei(balance));
    assert(fromWei(balance) > 0);

    const staked = await distRewards.balanceOf(wallet.address);
    console.log("\tDAI 'staked':", fromWei(staked));
    assert(fromWei(staked) > 0);
  });

  it("should redeem DAI from Aave", async function () {
    await time.advanceBlock();
    await time.increase(time.duration.days(5));

    const _balance = await aDai.balanceOf(wallet.address);
    const _aave = new web3.eth.Contract(aave.abi, aave.address);

    const data = await _aave.methods
      .redeemAToken(DAI, _balance, 0, 0, 1)
      .encodeABI();

    const tx = await wallet.execute([aave.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await aDai.balanceOf(wallet.address);
    console.log("\taDAI remaining:", fromWei(balance));
    assert(fromWei(balance) < 0.001); // there is some dust for the interest earned

    const staked = await distRewards.balanceOf(wallet.address);
    console.log("\tDAI 'staked':", fromWei(staked));
  });

  it("should have ETHA rewards earned", async function () {
    const earned = await distRewards.earned(wallet.address);
    console.log("\tETHA earned:", fromWei(earned));
    assert(fromWei(earned) > 0); // there is some dust for the interest earned
  });

  it("should claim ETHA rewards earned", async function () {
    const data = await _claim.methods.claimRewardsLending(DAI).encodeABI();

    const tx = await wallet.execute([claim.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await etha.balanceOf(wallet.address);
    console.log("\tETHA received:", fromWei(balance));
    assert(fromWei(balance) > 0); // there is some dust for the interest earned
  });

  it("should claim MATIC rewards earned", async function () {
    const _balance = await incentives.getRewardsBalance(
      [amDAI],
      wallet.address
    );

    const data = await _claim.methods
      .claimAaveRewards([amDAI], _balance)
      .encodeABI();

    const tx = await wallet.execute([claim.address], [data], {
      from: user,
      gas: web3.utils.toHex(5e6),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balance = await wmatic.balanceOf(wallet.address);
    console.log("\tWMATIC received:", fromWei(balance));
    assert(fromWei(balance) > 0); // there is some dust for the interest earned
  });
});
