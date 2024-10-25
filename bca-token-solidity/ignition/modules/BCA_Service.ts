const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

import service_contracts from "../deploy_services.json";

// local node
import deployed_address from "../deployments/chain-31337/deployed_addresses.json"

// Amoy testnet
// import deployed_address from "../deployments/chain-80002/deployed_addresses.json"

const BCAServiceModule = buildModule("BCA_Service", (m) => {

  let bcaservices = []
  let counter = 0;

  service_contracts.forEach(def => {
    console.log(`  deploying contract ${def.name} with provider=${def.providerAddress}`);
    const id = "BCAServiceContract" + ("000" + counter).slice(-4);
    const bcaservice = m.contract("BCAServiceContract", [def.providerAddress, deployed_address["BCA_Token#BCAServiceToken"], BigInt(def.dayPrice)], {id});
    bcaservices.push(bcaservice);
    counter += 1;
  });

  return { bcaservices };
});

module.exports = BCAServiceModule;
