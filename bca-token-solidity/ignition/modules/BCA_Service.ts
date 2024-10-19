const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// local node
import deployed_address from "../deployments/chain-31337/deployed_addresses.json"

// Amoy testnet
// import deployed_address from "../deployments/chain-80002/deployed_addresses.json"

const BCAServiceModule = buildModule("BCA_Service", (m) => {
  const one_token: bigint = 10n ** 18n
  const tick_price: bigint = (2n * one_token) / 24n / 3600n  // two tokens a day; per second
  const bcaservice = m.contract("BCAServiceContract", [deployed_address["BCA_Token#BCAServiceToken"],"0xBe371e774E8b0c87912Eb64BE1e2851c5b702B38", tick_price]);

  return { bcaservice };
});

module.exports = BCAServiceModule;
