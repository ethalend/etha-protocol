const { expect } = require("hardhat");

const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

const MULTISIG = "0xA4BD448BF09081740f9006C8f4D60d9bD2659D89";
const DEPLOYER = "0xB0Dd96118594903baCb2746eB228550C10B2b1DA";
const REGISTRY = "0x583B965462e11Da63D1d4bC6D2d43d391F79af1f";
const PROXY_ADMIN = "0x25Ec206A6921AEdBf80A6E4F88b9aC2112ebAe24";
const MEMORY = "0x7f3584b047e3c23fC7fF1Fb2aC55130ac2162e20";

// Testing previous upgrade
contract("Registry", ([]) => {
  before(async function () {
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [DEPLOYER],
    });

    deployer = await ethers.provider.getSigner(DEPLOYER);

    registry = await ethers.getContractAt("EthaRegistry", REGISTRY, deployer);
    proxyAdmin = await ethers.getContractAt(
      [
        {
          inputs: [
            {
              internalType: "address",
              name: "owner",
              type: "address",
            },
          ],
          stateMutability: "nonpayable",
          type: "constructor",
        },
        {
          anonymous: false,
          inputs: [
            {
              indexed: true,
              internalType: "address",
              name: "previousOwner",
              type: "address",
            },
            {
              indexed: true,
              internalType: "address",
              name: "newOwner",
              type: "address",
            },
          ],
          name: "OwnershipTransferred",
          type: "event",
        },
        {
          inputs: [
            {
              internalType: "contract TransparentUpgradeableProxy",
              name: "proxy",
              type: "address",
            },
            {
              internalType: "address",
              name: "newAdmin",
              type: "address",
            },
          ],
          name: "changeProxyAdmin",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "contract TransparentUpgradeableProxy",
              name: "proxy",
              type: "address",
            },
          ],
          name: "getProxyAdmin",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "contract TransparentUpgradeableProxy",
              name: "proxy",
              type: "address",
            },
          ],
          name: "getProxyImplementation",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "owner",
          outputs: [
            {
              internalType: "address",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "renounceOwnership",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "address",
              name: "newOwner",
              type: "address",
            },
          ],
          name: "transferOwnership",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "contract TransparentUpgradeableProxy",
              name: "proxy",
              type: "address",
            },
            {
              internalType: "address",
              name: "implementation",
              type: "address",
            },
          ],
          name: "upgrade",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "contract TransparentUpgradeableProxy",
              name: "proxy",
              type: "address",
            },
            {
              internalType: "address",
              name: "implementation",
              type: "address",
            },
            {
              internalType: "bytes",
              name: "data",
              type: "bytes",
            },
          ],
          name: "upgradeAndCall",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      PROXY_ADMIN,
      deployer
    );
  });

  it("should get correct fee recipient", async function () {
    const feeRecipient = await registry.feeRecipient();
    expect(feeRecipient).to.be.equal(MULTISIG);
  });

  it("should not get any fee manager address", async function () {
    await expectRevert.unspecified(registry.getFeeManager());
  });

  it("should upgrade registry", async function () {
    registryV2 = await ethers.getContractFactory("EthaRegistry");
    const res = await registryV2.deploy();
    await proxyAdmin.upgrade(REGISTRY, res.address);

    const impl = await proxyAdmin.getProxyImplementation(REGISTRY);

    expect(impl).to.be.equal(res.address);
  });

  it("should be able to set fee manager address", async function () {
    FeeManager = await ethers.getContractFactory("FeeManager");
    const res = await FeeManager.deploy();

    const tx = await registry.changeFeeManager(res.address);
    const { events } = await tx.wait();
    expect(events[0].event).to.be.equal("FeeManagerUpdated");

    const feeManager = await registry.getFeeManager();
    expect(feeManager).to.be.equal(res.address);
  });

  it("should not change storage after upgrade", async function () {
    const feeRecipient = await registry.feeRecipient();
    expect(feeRecipient).to.be.equal(MULTISIG);

    const memoryAddr = await registry.memoryAddr();
    expect(memoryAddr).to.be.equal(MEMORY);

    const notAllowed = await registry.notAllowed(
      "0x27f8d03b3a2196956ed754badc28d73be8830a6e"
    );
    expect(notAllowed).to.be.true;
  });
});
