import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";

  describe("BCA Funding", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, minter, burner, provider, user1, user2, cron] = await hre.ethers.getSigners();

        const Token = await hre.ethers.getContractFactory("BCAServiceToken");
        const tokenContract = await Token.deploy("Test token", "TOK1", minter, burner);
        const precision: bigint = await tokenContract.decimals().then(d => { if (d == 0n) {return 18n;} else {return d}; });

        const Contract1 = await hre.ethers.getContractFactory("BCAServiceInstance");
        const daily_price = 1n;  // 1 token per 24h
        const day_price = (daily_price * BigInt(10n**precision));
        const serviceContract = await Contract1.deploy(provider, tokenContract.getAddress(), user1, day_price);

        const Contract2 = await hre.ethers.getContractFactory("BCAServiceFunding24");
        const daily_funds = 101n;  // 1.01 token per 24h
        const day_funds = (daily_funds * BigInt(10n**precision) / 100n);
        const target_contract = serviceContract.getAddress();
        const fundingContract = await Contract2.deploy(user1, target_contract, tokenContract.getAddress(), day_funds);

        // minting some tokens to the users
        const one_token = 1n * BigInt(10n**precision);
        expect(await tokenContract.connect(minter).mint(user1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user2, 10n*one_token);

        const startblocktime: bigint = BigInt(await time.increase(30));

        return { token: { tokenContract, one_token, owner, minter, burner, provider, user1, user2 },
                 funding: { fundingContract, day_funds, cron },
                 service: { serviceContract, provider, user1, user2 } };
    }

    describe("Deployment", function () {
        it("Funding contract: should set the right target contract", async function () {
            const { funding, service } = await loadFixture(deployContract);
            expect(await funding.fundingContract.targetContract()).to.equal(
                await service.serviceContract.getAddress()
            );
        });

        it("Funding contract: should set the right daily amount", async function () {
            const { funding } = await loadFixture(deployContract);
            expect(await funding.fundingContract.dailyAmount()).to.equal(
                funding.day_funds
            );
        });

        it("Funding contract: should set the right token", async function () {
            const { token, funding } = await loadFixture(deployContract);
            expect(await funding.fundingContract.token()).to.equal(
                await token.tokenContract.getAddress()
            );
        });
    });

    describe("Deposit functionality", function () {
        it("Should allow deposit when properly funded and approved", async function () {
            const { token, funding, service } = await loadFixture(deployContract);

            // Approve funding contract to spend user1's tokens
            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 10n
            );

            // Initial deposit should succeed
            await expect(funding.fundingContract.connect(funding.cron).deposit())
                .to.emit(funding.fundingContract, "DepositMade")
                .withArgs(service.serviceContract.getAddress(), funding.day_funds, anyValue);
        });

        it("Should revert if user has insufficient balance for allowance", async function () {
            const { token, funding } = await loadFixture(deployContract);

            // Transfer all tokens from user1 to user2
            await token.tokenContract.connect(token.user1).transfer(
                token.user2.address,
                await token.tokenContract.balanceOf(token.user1.address)
            );

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds
            );

            await expect(
                funding.fundingContract.connect(funding.cron).deposit()
            ).to.be.revertedWith("Insufficient balance in owner's wallet");
        });

        it("Should revert if allowance is insufficient", async function () {
            const { token, funding } = await loadFixture(deployContract);

            // Approve one less than required amount
            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds - 1n
            );

            await expect(
                funding.fundingContract.connect(funding.cron).deposit()
            ).to.be.revertedWith("Insufficient allowance from owner");
        });

        it("Should revert if called twice within 24 hours", async function () {
            const { token, funding } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 2n
            );

            // First deposit
            await funding.fundingContract.connect(funding.cron).deposit();

            // Second deposit should fail
            await expect(
                funding.fundingContract.connect(token.user1).deposit()
            ).to.be.revertedWith("24 hours have not passed since last deposit");
        });

        it("Should allow deposit after 24 hours", async function () {
            const { token, funding } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 2n
            );

            // First deposit
            await funding.fundingContract.connect(funding.cron).deposit();

            // Increase time by 24 hours
            await time.increase(24 * 60 * 60);

            // Second deposit should succeed
            await expect(
                funding.fundingContract.connect(funding.cron).deposit()
            ).to.not.be.reverted;
        });
    });

    describe("canDeposit functionality", function () {
        it("Should return true when all conditions are met", async function () {
            const { token, funding } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds
            );

            expect(await funding.fundingContract.connect(funding.cron).canDeposit())
                .to.be.true;
        });

        it("Should return false right after a deposit", async function () {
            const { token, funding } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 2n
            );

            await funding.fundingContract.connect(funding.cron).deposit();

            expect(await funding.fundingContract.connect(funding.cron).canDeposit())
                .to.be.false;
        });

        it("Should return true again after 24 hours", async function () {
            const { token, funding } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 2n
            );

            await funding.fundingContract.connect(funding.cron).deposit();
            await time.increase(24 * 60 * 60);

            expect(await funding.fundingContract.connect(funding.cron).canDeposit())
                .to.be.true;
        });
    });

    describe("Integration with service contract", function () {
        it("Should successfully deposit to service contract", async function () {
            const { token, funding, service } = await loadFixture(deployContract);

            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds
            );

            const initialBalance = await token.tokenContract.balanceOf(
                service.serviceContract.getAddress()
            );

            await funding.fundingContract.connect(funding.cron).deposit();

            // advance time and create a new block
            const block1 = BigInt(await time.increase(30));

            // the start time must be registered on the first succesfull call to "makeDeposit"
            expect(await service.serviceContract.startTime()).to.lessThanOrEqual(block1, "not right");

            expect(await token.tokenContract.balanceOf(
                service.serviceContract.getAddress()
            )).to.equal(initialBalance + funding.day_funds);

        });

        it("Should correctly handle the entire flow", async function () {
            const { token, funding, service } = await loadFixture(deployContract);

            // Initial approval
            await token.tokenContract.connect(token.user1).approve(
                funding.fundingContract.getAddress(),
                funding.day_funds * 3n
            );

            // First deposit
            await funding.fundingContract.connect(funding.cron).deposit();

            // advance time and create a new block
            const block1 = BigInt(await time.increase(30));

            // Try immediate deposit (should fail)
            await expect(
                funding.fundingContract.connect(funding.cron).deposit()
            ).to.be.revertedWith("24 hours have not passed since last deposit");

            // Wait 24 hours
            await time.increase(24 * 60 * 60);

            // Second deposit should succeed
            await expect(
                funding.fundingContract.connect(funding.cron).deposit()
            ).to.not.be.reverted;

            // the start time must be registered on the first succesfull call to "deposit"
            expect(await service.serviceContract.startTime()).to.lessThanOrEqual(block1, "not right");

            // Verify final balance in service contract
            expect(await token.tokenContract.balanceOf(
                service.serviceContract.getAddress()
            )).to.equal(funding.day_funds * 2n);
        });
    });
});
