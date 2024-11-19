import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";

  describe("BCA Service Manager", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, minter, burner, provider1, provider2, user1, user2] = await hre.ethers.getSigners();

        const Token = await hre.ethers.getContractFactory("BCAServiceToken");
        const tokenContract = await Token.deploy("Test token", "TOK1", minter, burner);
        const precision: bigint = await tokenContract.decimals().then(d => { if (d == 0n) {return 18n;} else {return d}; });

        const Manager = await hre.ethers.getContractFactory("BCAServiceManager");
        const serviceManager = await Manager.deploy(tokenContract.getAddress());

        const addrController1 = await (await serviceManager.connect(owner).newController(provider1)).wait().then(_ => serviceManager.connect(owner).getControllerAddress(provider1));
        const serviceController1 = await hre.ethers.getContractAt("BCAServiceController", addrController1)
        const addrController2 = await (await serviceManager.connect(owner).newController(provider2)).wait().then(_ => serviceManager.connect(owner).getControllerAddress(provider2));
        const serviceController2 = await hre.ethers.getContractAt("BCAServiceController", addrController2)

        // minting some tokens to the users
        const one_token = 1n * BigInt(10n**precision);
        expect(await tokenContract.connect(minter).mint(provider1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, provider1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(provider2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, provider2, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user2, 10n*one_token);

        const startblocktime: bigint = BigInt(await time.increase(30));

        return { token: { tokenContract, one_token, owner, minter, burner, user1, user2 },
                 sm: { serviceManager, provider1, provider2 },
                 sc1: { serviceController1, provider1 },
                 sc2: { serviceController2, provider2 } };
    }

    describe("Deployment", function () {
        it("Should have already deployed controllers", async function () {
            const { sm } = await loadFixture(deployContract);
            expect(await sm.serviceManager.countServiceControllers()).to.equal(
                2
            );
        });

        it("Should set the right provider", async function () {
            const { sc1 } = await loadFixture(deployContract);
            expect(await sc1.serviceController1.providerAddress()).to.equal(
                sc1.provider1.address
            );
        });

        it("Should set the right provider", async function () {
            const { sc2 } = await loadFixture(deployContract);
            expect(await sc2.serviceController2.providerAddress()).to.equal(
                sc2.provider2.address
            );
        });
    });

    describe("Create new services", function () {
        it("Should emit ServiceDeployed on new service creation", async function () {
            const { sc1, sc2 } = await loadFixture(deployContract);

            await expect(sc1.serviceController1.connect(sc1.provider1).newService(3, 1n * 10n**18n))
                .to.emit(sc1.serviceController1, "ServiceDeployed")
                .withArgs(anyValue);
            await expect(sc2.serviceController2.connect(sc2.provider2).newService(99, 1n * 10n**18n / 10n))
                .to.emit(sc2.serviceController2, "ServiceDeployed")
                .withArgs(anyValue);
        });

    });
});
