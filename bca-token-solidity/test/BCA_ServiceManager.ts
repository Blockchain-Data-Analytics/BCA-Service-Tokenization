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

        const Contract1 = await hre.ethers.getContractFactory("BCAServiceManager");
        const serviceManager1 = await Contract1.deploy(provider1, tokenContract.getAddress());

        const Contract2 = await hre.ethers.getContractFactory("BCAServiceManager");
        const serviceManager2 = await Contract1.deploy(provider2, tokenContract.getAddress());

        // minting some tokens to the users
        const one_token = 1n * BigInt(10n**precision);
        expect(await tokenContract.connect(minter).mint(provider1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, provider1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(provider2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, provider2, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user2, 10n*one_token);

        const startblocktime: bigint = BigInt(await time.increase(30));

        return { token: { tokenContract, one_token, owner, minter, burner, user1, user2 },
                 sm1: { serviceManager1, provider1 },
                 sm2: { serviceManager2, provider2 } };
    }

    describe("Deployment", function () {
        it("Funding contract: should set the right provider", async function () {
            const { sm1 } = await loadFixture(deployContract);
            expect(await sm1.serviceManager1.providerAddress()).to.equal(
                sm1.provider1.address
            );
        });

        it("Funding contract: should set the right provider", async function () {
            const { sm2 } = await loadFixture(deployContract);
            expect(await sm2.serviceManager2.providerAddress()).to.equal(
                sm2.provider2.address
            );
        });
    });

    describe("Create new services", function () {
        it("Should emit ServiceDeployed on new service creation", async function () {
            const { sm1, sm2 } = await loadFixture(deployContract);

            await expect(sm1.serviceManager1.connect(sm1.provider1).newService(3, 1n * 10n**18n))
                .to.emit(sm1.serviceManager1, "ServiceDeployed")
                .withArgs(anyValue);
            await expect(sm2.serviceManager2.connect(sm2.provider2).newService(99, 1n * 10n**18n / 10n))
                .to.emit(sm2.serviceManager2, "ServiceDeployed")
                .withArgs(anyValue);
        });

    });
});
