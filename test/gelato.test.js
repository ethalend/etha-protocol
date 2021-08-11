const {
  deployments: { fixture },
  ethers,
  web3,
} = require("hardhat");

const { MATIC } = require("../deploy/utils");

const POKE_ME = "0x00e8f432b33D1C550E02Ff55c8413Fd50a931c39";
const GELATO = "0x7598e84B2E114AB62CAB288CE5f7d5f6bad35BbA";
const TREASURY = "0xA8a7BBe83960B29789d5CB06Dcd2e6C1DF20581C";

const HARVESTER = "0xa248c6df64c3Ac2f7508A8F8E74933e3f4bF6169";
const VAULT = "0x4e5b645B69e873295511C6cA5B8951c3ff4F74F4";

contract("Gelato", () => {
  let gelato, pokeMe, treasury, resolver;

  before(async function () {
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
        inputs: [
          {
            type: "address",
            name: "harvester",
          },
          ,
          {
            type: "address",
            name: "vault",
          },
        ],
      },
      [HARVESTER, VAULT]
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

  it("should execute task", async function () {
    const { canExec, execPayload } = await resolver.checker(HARVESTER, VAULT);

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
  });
});
