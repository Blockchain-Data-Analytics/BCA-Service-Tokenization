import {
    time,
    loadFixture,
  } from "@nomicfoundation/hardhat-toolbox/network-helpers";
  import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
  import { expect } from "chai";
  import hre from "hardhat";
    
  describe("BCA Service", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployContract() {
        // Contracts are deployed using the first signer/account by default
        const [owner, minter, burner, provider, user1, user2] = await hre.ethers.getSigners();
    
        const Token = await hre.ethers.getContractFactory("BCAServiceToken");
        const tokenContract = await Token.deploy("Test token", "TOK1", minter, burner);
        const precision: bigint = await tokenContract.decimals().then(d => { if (d == 0n) {return 18n;} else {return d}; });

        const Contract = await hre.ethers.getContractFactory("BCAServiceContract");
        const daily_price = 1n;  // 1 token per 24h
        const tick_price = (daily_price * BigInt(10n**precision)) / 24n / 3600n;
        assert(tick_price > 0n, "tick price must be > 0: " + (tick_price.toString()));
        console.log(`tick price: ${tick_price}`)
        const serviceContract = await Contract.deploy(provider, tokenContract.getAddress(), tick_price);

        // minting some tokens to the users
        const one_token = 10n * BigInt(10n^precision);
        expect(await tokenContract.connect(minter).mint(user1.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user1, 10n*one_token);
        expect(await tokenContract.connect(minter).mint(user2.address, 10n*one_token)).to.changeTokenBalance(tokenContract, user2, 10n*one_token);
      
        const startblocktime: bigint = BigInt(await time.increase(30));

        return { token: { tokenContract, one_token, owner, minter, burner, provider, user1, user2 },
                 service: { serviceContract, startblocktime, provider, user1, user2 } };
    }
  
    describe("Deployment", function () {
      it("Should set the right name", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        expect(await token.tokenContract.name()).to.equal("Test token");
    });
    
    it("Should set the right provider", async function () {
        const { token, service } = await loadFixture(deployContract);
        
        expect(await service.serviceContract.providerAddress() == service.provider.address)
      });
    
    });
  
  describe("Deposit from user", function () {
    it("The user deposits to the contract and thus starts the service", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        let deposit = token.one_token * 2n;

        expect(await service.serviceContract.startTime()).to.eq(0, "good! not yet started");

        // approve deposit amounts to be spent by the service contract
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block1 = BigInt(await time.increase(30));

        // advance time and create a new block
        const block2 = BigInt(await time.increase(30));

        // service contract is subscribed by user1; cannot be subscribed by another user
        await expect(service.serviceContract.connect(service.user2).makeDeposit(token.one_token * 1n)).to.be.revertedWithCustomError(service.serviceContract, 'AlreadySubscribed()');

        // advance time and create a new block
        const block3 = BigInt(await time.increase(30));

        // increase the deposit - also increase the allowance
        deposit = token.one_token * 3n;
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block4 = BigInt(await time.increase(30));

        // the start time must be registered on the first succesfull call to "makeDeposit"
        expect(await service.serviceContract.startTime()).to.lessThanOrEqual(block1, "not right");

        // the user subscribed to the service must be user1
        expect(await  service.serviceContract.userAddress()).to.equal(service.user1.address)

    });
  });
  

  });

function assert(pred: boolean, msg: string) {
    if (! pred) {
       throw new Error(`assertion failed. ${msg}`);
    }
}
  