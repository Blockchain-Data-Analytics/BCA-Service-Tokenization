import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre from "hardhat";
import { token } from "../typechain-types/@openzeppelin/contracts";

describe("BCA Token", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, minter, burner, user1, user2] = await hre.ethers.getSigners();

    const Contract = await hre.ethers.getContractFactory("BCAServiceToken");
    const tokenContract = await Contract.deploy("Test token", "TST1", minter, burner);

    return { tokenContract, owner, minter, burner, user1, user2 };
  }

  describe("Deployment", function () {
    it("Should set the right name", async function () {
      const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

      expect(await tokenContract.name()).to.equal("Test token");
    });

    it("Should set the right owner", async function () {
      const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

      const default_owner_role = await tokenContract.DEFAULT_ADMIN_ROLE();
      expect(await tokenContract.hasRole(default_owner_role, owner.address)).to.equal(true);
      expect(await tokenContract.hasRole(default_owner_role, minter.address)).to.equal(false);
      expect(await tokenContract.hasRole(default_owner_role, burner.address)).to.equal(false);
      expect(await tokenContract.hasRole(default_owner_role, user1.address)).to.equal(false);
      expect(await tokenContract.hasRole(default_owner_role, user2.address)).to.equal(false);
      expect(await tokenContract.serviceAddress()).to.equal(owner.address);
    });

    it("Should set the right minter", async function () {
      const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

      const minter_role = await tokenContract.MINTER_ROLE();
      expect(await tokenContract.hasRole(minter_role, minter.address)).to.equal(true);
      expect(await tokenContract.hasRole(minter_role, burner.address)).to.equal(false);
      expect(await tokenContract.hasRole(minter_role, owner.address)).to.equal(false);
      expect(await tokenContract.hasRole(minter_role, user1.address)).to.equal(false);
      expect(await tokenContract.hasRole(minter_role, user2.address)).to.equal(false);
    });

    it("Should set the right burner", async function () {
      const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

      const burner_role = await tokenContract.BURNER_ROLE();
      expect(await tokenContract.hasRole(burner_role, burner.address)).to.equal(true);
      expect(await tokenContract.hasRole(burner_role, minter.address)).to.equal(false);
      expect(await tokenContract.hasRole(burner_role, owner.address)).to.equal(false);
      expect(await tokenContract.hasRole(burner_role, user1.address)).to.equal(false);
      expect(await tokenContract.hasRole(burner_role, user2.address)).to.equal(false);
    });

  });

describe("Ownership", function () {
  it("Pass ownership of this contract to another address", async function () {
    const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

    expect(await tokenContract.connect(owner).setServiceAddress(user1.address));
    // check that the previous account will have its role revoked
    expect(tokenContract.connect(owner).setServiceAddress(user2.address)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
    // somebody else cannot do this
    expect(tokenContract.connect(user2).setServiceAddress(user1.address)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
    // further pass the role to some other account
    expect(await tokenContract.connect(user1).setServiceAddress(user2.address));
    // check that the previous account will have its role revoked
    expect(tokenContract.connect(user1).setServiceAddress(user2.address)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
  });
});

describe("Minting", function () {
  it("Minting of new tokens", async function () {
    const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

    expect(await tokenContract.connect(minter).mint(user1.address, 100000000)).to.changeTokenBalance(tokenContract, user1, +100000000);
    expect(await tokenContract.connect(minter).totalSupply()).to.equal(100000000);
    expect(tokenContract.connect(user2).mint(user1.address, 999999999999)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");

    // change of minter address
    expect(await tokenContract.connect(owner).setMinterAddress(user2.address));
    expect(await tokenContract.connect(user2).mint(user1.address, 100000000)).to.changeTokenBalance(tokenContract, user1, +100000000);
    expect(await tokenContract.connect(user2).totalSupply()).to.equal(200000000);
  });
});

describe("Transfer", function () {
  it("Transfer of tokens", async function () {
    const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

    expect(await tokenContract.connect(minter).mint(user2.address, 100000000)).to.changeTokenBalance(tokenContract, user2, +100000000);
    expect(await tokenContract.connect(user2).transfer(tokenContract.serviceAddress(), 50000000)).to.changeTokenBalances(tokenContract, [user2,tokenContract.serviceAddress()], [-50000000,+50000000]);
    expect(await tokenContract.connect(user2).transfer(tokenContract.serviceAddress(), 20000000)).to.changeTokenBalances(tokenContract, [user2,tokenContract.serviceAddress()], [-20000000,+20000000]);
    expect(await tokenContract.connect(burner).burn(tokenContract.serviceAddress(), 70000000)).to.changeTokenBalance(tokenContract, tokenContract.serviceAddress(), -70000000);

    expect(tokenContract.connect(user2).transfer(user1.address, 999999999999)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
  });
});

describe("TransferFrom", function () {
  it("Transfer allowance from/to accounts", async function () {
    const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

    expect(await tokenContract.connect(minter).mint(user2.address, 100000000)).to.changeTokenBalance(tokenContract, user2, +100000000);

    // cannot use "transferFrom" as no allowance available - use "transfer"
    expect(tokenContract.connect(user2).transferFrom(user2.address,tokenContract.serviceAddress(), 50000000)).to.revertedWithCustomError(tokenContract, "ERC20InsufficientAllowance");
    // cannot give allowance to another user
    expect(tokenContract.connect(user2).transferFrom(user2.address,user1.address, 2999999)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
  });
});

describe("Burning", function () {
  it("Burning of tokens", async function () {
    const { tokenContract, owner, minter, burner, user1, user2 } = await loadFixture(deployContract);

    expect(await tokenContract.connect(minter).mint(user2.address, 100000000)).to.changeTokenBalance(tokenContract, user2, +100000000);
    expect(await tokenContract.connect(user2).transfer(tokenContract.serviceAddress(), 50000000)).to.changeTokenBalances(tokenContract, [user2,tokenContract.serviceAddress()], [-50000000,+50000000]);
    expect(await tokenContract.connect(burner).burn(tokenContract.serviceAddress(), 50000000)).to.changeTokenBalance(tokenContract, tokenContract.serviceAddress(), -50000000);
    expect(await tokenContract.connect(user1).totalSupply()).to.equal(50000000);
    expect(tokenContract.connect(user2).burn(user1.address, 9999999)).to.revertedWithCustomError(tokenContract, "AccessControlUnauthorizedAccount");
    // change of burner address
    expect(await tokenContract.connect(owner).setBurnerAddress(user1.address));
    expect(await tokenContract.connect(user2).transfer(tokenContract.serviceAddress(), 10000000)).to.changeTokenBalances(tokenContract, [user2,tokenContract.serviceAddress()], [-10000000,+10000000]);
    expect(await tokenContract.connect(user1).burn(tokenContract.serviceAddress(), 10000000)).to.changeTokenBalance(tokenContract, tokenContract.serviceAddress(), -10000000);
    expect(await tokenContract.connect(user1).totalSupply()).to.equal(40000000);
  });
});

});
