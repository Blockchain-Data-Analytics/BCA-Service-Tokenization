const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

const BCATokenModule = buildModule("BCA_Token", (m) => {
  const bcatoken = m.contract("BCAServiceToken", ["BCA_ServiceToken","BCA1","0x70997970C51812dc3A010C7d01b50e0d17dc79C8","0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"]);

  return { bcatoken };
});

module.exports = BCATokenModule;
