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

        const Contract = await hre.ethers.getContractFactory("BCAServiceInstance");
        const daily_price = 1n;  // 1 token per 24h
        const day_price = (daily_price * BigInt(10n**precision));
        assert(day_price > 0n, "tick price must be > 0: " + (day_price.toString()));
        // console.log(`tick price: ${day_price}`)
        const serviceContract = await Contract.deploy(provider, tokenContract.getAddress(), user1, day_price);

        // minting some tokens to the users
        const one_token = 1n * BigInt(10n**precision);
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
  describe("Interrogate a service contract", function () {
    it("The user cannot call the provider's balance", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 2n;
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      await expect(service.serviceContract.connect(service.user1).balanceProvider()).to.be.revertedWithCustomError(service.serviceContract, 'UnAuthorized()');
    });
    it("The provider cannot call the users's balance", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 2n;
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      await expect(service.serviceContract.connect(service.provider).balanceUser()).to.be.revertedWithCustomError(service.serviceContract, 'UnAuthorized()');
    });
    it("The user cannot see his balance when service not started", async function () {
      const { token, service } = await loadFixture(deployContract);

      await expect(service.serviceContract.connect(service.user1).balanceUser()).to.be.revertedWithCustomError(service.serviceContract, 'NotStarted()');
    });
    it("The provider cannot see his balance when service not started", async function () {
      const { token, service } = await loadFixture(deployContract);

      await expect(service.serviceContract.connect(service.provider).balanceProvider()).to.be.revertedWithCustomError(service.serviceContract, 'NotStarted()');
    });
    it("Cannot stop a stopped contract", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 2n;
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(30));

      expect(await service.serviceContract.connect(service.user1).stop()).to.emit(service.serviceContract, "ServiceStopped").withArgs('ticks');
      await expect(service.serviceContract.connect(service.user1).stop()).to.be.revertedWithCustomError(service.serviceContract, 'AlreadyStopped()');
    });
    it("A third user cannot stop a contract", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 2n;
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(30));

      await expect(service.serviceContract.connect(service.user2).stop()).to.be.revertedWithCustomError(service.serviceContract, 'UnAuthorized()');
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

        // increase the deposit - also increase the allowance
        deposit = token.one_token * 3n;
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block4 = BigInt(await time.increase(30));

        // the start time must be registered on the first succesfull call to "makeDeposit"
        expect(await service.serviceContract.startTime()).to.lessThanOrEqual(block1, "not right");

        // the user subscribed to the service must be user1
        expect(await service.serviceContract.userAddress()).to.equal(service.user1.address);

        // check the deposit
        expect(await service.serviceContract.deposit()).to.equal(5n * token.one_token);

        // check the user's balance, and the provider's
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.lessThan(5n * token.one_token);
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.lessThan(1n * token.one_token);

    });
  });
  
  describe("Run a service", function () {
    it("The user deposits to the contract and thus starts the service, then stops the service", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        let deposit = token.one_token * 1n;  // this is sufficient for one day

        // approve deposit amounts to be spent by the service contract
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block1 = BigInt(await time.increase(12 * 3600));

        // the user stops the service
        expect(await service.serviceContract.connect(service.user1).stop()).to.emit(service.serviceContract, "ServiceStopped").withArgs('ticks');

        // check the user's balance
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.approximately(5n * token.one_token / 10n, 100000000000000n);
        // and the provider's: cannot grow larger than the deposit
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.approximately(5n * token.one_token / 10n, 100000000000000n);

        // check the end time in the contract
        expect(await service.serviceContract.endTime()).to.not.equal(0);
    });
  
    it("The user deposits to the contract and thus starts the service, then withdraws which stops the service", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        let deposit = token.one_token * 1n;  // this is sufficient for one day

        // approve deposit amounts to be spent by the service contract
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block1 = BigInt(await time.increase(12 * 3600));

        // check the user's balance: should be ~ 0.5; will pay a tick until next tx
        const ubal = await service.serviceContract.connect(service.user1).balanceUser() - (await service.serviceContract.dayPrice() / 24n / 3600n);
        const rem = await service.serviceContract.deposit()
        // console.log(`user's balance: ${ubal}  deposit: ${rem}  24h price: ${await service.serviceContract.dayPrice()}`)

        // the user withdraws from the contract which stops the service
        expect(await service.serviceContract.connect(service.user1).withdrawUser(ubal)).to.emit(service.serviceContract, "ServiceStopped").withArgs('ticks');

        // advance time and create a new block
        const block2 = BigInt(await time.increase(3600));

        // check the user's balance
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.approximately(0n, 10000n);
        // and the provider's: cannot grow larger than the deposit
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.approximately(5n * token.one_token / 10n, 100000000000000n);

        // check the end time in the contract
        expect(await service.serviceContract.endTime()).to.not.equal(0);
    });
  });
  
  describe("Cannot deposit to a stopped service", function () {
    it("The user stops a service, then sends deposits to the service which must fail", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        let deposit = token.one_token * 1n;  // this is sufficient for one day

        // approve deposit amounts to be spent by the service contract
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block1 = BigInt(await time.increase(23 * 3600));

        // check the deposit (minus the setup fee)
        expect(await service.serviceContract.deposit()).to.equal(1n * token.one_token);

        // check the user's balance, and the provider's
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.lessThan(1n * token.one_token / 2n);
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.greaterThan(1n * token.one_token / 2n);

        // advance time and create a new block
        const block2 = BigInt(await time.increase(3620)); // 20 seconds longer

        // check the user's balance
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.equal(0n);
        // and the provider's: cannot grow larger than the deposit
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.approximately(1n * token.one_token, 10000n);

        // the provider withdraws the funds, which stops the service
        expect(await service.serviceContract.connect(service.provider).withdrawProvider(1n * token.one_token)).to.changeTokenBalances(token.tokenContract, [service.serviceContract.getAddress(),service.provider.address], [1n * token.one_token, - 1n * token.one_token]);

        // the user tries to make a new deposit which must fail with 'AlreadyStopped'
        await expect(service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.be.revertedWithCustomError(service.serviceContract, 'AlreadyStopped()')
      });
  });
  
  describe("Withdraw from a service", function () {
    it("The user deposits to the contract and thus starts the service. The provider withdraws some amount.", async function () {
        const { token, service } = await loadFixture(deployContract);
  
        let deposit = token.one_token * 1n;  // this is sufficient for one day

        // approve deposit amounts to be spent by the service contract
        await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
        expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

        // advance time and create a new block
        const block1 = BigInt(await time.increase(12 * 3600));

        // check the deposit (minus the setup fee)
        expect(await service.serviceContract.deposit()).to.equal(1n * token.one_token);

        // check the user's balance, and the provider's
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.approximately(1n * token.one_token / 2n, 10000n);
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.approximately(1n * token.one_token / 2n, 10000n);

        // advance time and create a new block
        const block2 = BigInt(await time.increase(20));
        
        // the provider withdraws some funds
        expect(await service.serviceContract.connect(service.provider).withdrawProvider(1n * token.one_token / 2n)).to.changeTokenBalances(token.tokenContract, [service.serviceContract.getAddress(),service.provider.address], [1n * token.one_token / 2n, - 1n * token.one_token / 2n]);

        // advance time and create a new block
        const block3 = BigInt(await time.increase(12 * 3600));

        // the provider withdraws some funds
        expect(await service.serviceContract.connect(service.provider).withdrawProvider(1n * token.one_token / 2n)).to.changeTokenBalances(token.tokenContract, [service.serviceContract.getAddress(),service.provider.address], [1n * token.one_token / 2n, - 1n * token.one_token / 2n]);

        // check the user's balance
        expect(await service.serviceContract.connect(service.user1).balanceUser()).to.equal(0n);
        // and the provider's: cannot grow larger than the deposit minus the retracted amounts
        expect(await service.serviceContract.connect(service.provider).balanceProvider()).to.equal(0n);
    });

    it("The user cannot withdraw the provider's balance.", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 1n;  // this is sufficient for one day

      // approve deposit amounts to be spent by the service contract
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(12 * 3600));

      // the user withdraws some funds
      await expect(service.serviceContract.connect(service.user1).withdrawProvider(1n * token.one_token / 2n)).to.be.revertedWithCustomError(service.serviceContract, 'UnAuthorized()');
    });

    it("The provider cannot withdraw the user's balance.", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 1n;  // this is sufficient for one day

      // approve deposit amounts to be spent by the service contract
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(12 * 3600));

      // the provider withdraws some funds
      await expect(service.serviceContract.connect(service.provider).withdrawUser(1n * token.one_token / 2n)).to.be.revertedWithCustomError(service.serviceContract, 'UnAuthorized()');
    });

    it("The user cannot withdraw more than the balance.", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 1n;  // this is sufficient for one day

      // approve deposit amounts to be spent by the service contract
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(12 * 3600));

      // the user withdraws some funds
      await expect(service.serviceContract.connect(service.user1).withdrawUser(6n * token.one_token / 10n)).to.be.revertedWithCustomError(service.serviceContract, 'InsufficientBalance');
    });

    it("The provider cannot withdraw more than the balance.", async function () {
      const { token, service } = await loadFixture(deployContract);

      let deposit = token.one_token * 1n;  // this is sufficient for one day

      // approve deposit amounts to be spent by the service contract
      await token.tokenContract.connect(service.user1).approve(service.serviceContract.getAddress(), deposit);
      expect(await service.serviceContract.connect(service.user1).makeDeposit(deposit)).to.changeTokenBalance(token.tokenContract, token.user1, - deposit);

      // advance time and create a new block
      const block1 = BigInt(await time.increase(12 * 3600));

      // the provider withdraws some funds
      await expect(service.serviceContract.connect(service.provider).withdrawProvider(6n * token.one_token / 10n)).to.be.revertedWithCustomError(service.serviceContract, 'InsufficientBalance');
    });
  });

  });

function assert(pred: boolean, msg: string) {
    if (! pred) {
       throw new Error(`assertion failed. ${msg}`);
    }
}
  