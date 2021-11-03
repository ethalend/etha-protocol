const {
  deployments: { fixture },
  ethers,
  web3,
} = require("hardhat");

const { MATIC } = require("../deploy/utils");

const POKE_ME = "0x00e8f432b33D1C550E02Ff55c8413Fd50a931c39";
const GELATO = "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA";
const TREASURY = "0xA8a7BBe83960B29789d5CB06Dcd2e6C1DF20581C";

const HARVESTER = "0x2ccd2B61c4eaF59C2397368ccD1F67b02A8B89C5";
const VAULT = "0x4e5b645B69e873295511C6cA5B8951c3ff4F74F4";
const VAULT2 = "0xb56AAb9696B95a75A6edD5435bc9dCC4b07403b0";

contract("Gelato", () => {
  let gelato, pokeMe, treasury, resolver;

  before(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: process.env.NODE_URL,
            blockNumber: 18349327,
          },
        },
      ],
    });

    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [GELATO],
    });

    [user] = await ethers.getSigners();

    gelato = await ethers.provider.getSigner(GELATO);

    await fixture(["Gelato"]);

    resolver = await ethers.getContract("Gelato");
    pokeMe = await ethers.getContractAt("IPokeMe", POKE_ME);
    treasury = await ethers.getContractAt("ITaskTreasury", TREASURY);
  });

  it("should set harvester in resolver", async function () {
    await resolver.setHarvester(HARVESTER);
  });

  it("should add vaults to queue", async function () {
    await resolver.addVault(VAULT);
    await resolver.addVault(VAULT2);

    expect(await resolver.getVault(0)).to.be.equal(VAULT);
    expect(await resolver.getVault(1)).to.be.equal(VAULT2);
  });

  it("should get correct gelato address from pokeMe", async function () {
    expect(await pokeMe.gelato()).to.be.equal(GELATO);
  });

  it("should create a task on pokeMe", async function () {
    const _execSelector = web3.eth.abi.encodeFunctionSignature({
      name: "harvestVault",
      type: "function",
      inputs: [
        {
          type: "address",
          name: "vault",
        },
      ],
    });

    const _resolverData = web3.eth.abi.encodeFunctionCall(
      {
        name: "checker",
        type: "function",
        inputs: [],
      },
      []
    );

    await pokeMe
      .connect(user)
      .createTask(HARVESTER, _execSelector, resolver.address, _resolverData);
  });

  it("should deposit funds to treasury", async function () {
    const amount = ethers.utils.parseEther("1");
    await treasury.connect(user).depositFunds(user.address, MATIC, amount, {
      value: amount,
    });

    const balance = await treasury.userTokenBalance(user.address, MATIC);
    expect(String(balance)).to.be.equal(String(amount));
  });

  it("should execute task to harvest first vault", async function () {
    _vault = await ethers.getContractAt("IVault", VAULT);

    const lastDistribution = await _vault.lastDistribution();
    console.log(String(lastDistribution));

    const { canExec, execPayload } = await resolver.checker();

    expect(canExec).to.be.true;

    await pokeMe
      .connect(gelato)
      .exec(
        ethers.utils.parseEther("0.05"),
        MATIC,
        user.address,
        HARVESTER,
        execPayload
      );

    const lastDistributionNew = await _vault.lastDistribution();
    console.log(String(lastDistributionNew));

    expect(Number(lastDistributionNew)).to.be.greaterThan(
      Number(lastDistribution)
    );
  });

  it("should execute task to harvest second vault", async function () {
    _vault = await ethers.getContractAt("IVault", VAULT2);

    const lastDistribution = await _vault.lastDistribution();

    const { canExec, execPayload } = await resolver.checker();

    expect(canExec).to.be.true;

    await pokeMe
      .connect(gelato)
      .exec(
        ethers.utils.parseEther("0.05"),
        MATIC,
        user.address,
        HARVESTER,
        execPayload
      );

    const lastDistributionNew = await _vault.lastDistribution();

    expect(Number(lastDistributionNew)).to.be.greaterThan(
      Number(lastDistribution)
    );
  });
});
