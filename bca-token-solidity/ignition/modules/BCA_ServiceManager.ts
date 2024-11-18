const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

// local node
import deployed_address from "../deployments/chain-31337/deployed_addresses.json"
// let owner = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
let provider = "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199"

// Amoy testnet
// import deployed_address from "../deployments/chain-80002/deployed_addresses.json"
// let owner = "0x1A8725f9A4295bb3b4E5321Ecb2c9185004fC76F"
// let provider = "0x480F8D64E9AE32E12C2B537d8347B8E035d43183"

const BCAServiceManagerModule = buildModule("BCA_ServiceManager", (m) => {

    const bcasrvmgr = m.contract("BCAServiceManager", [provider, deployed_address["BCA_Token#BCAServiceToken"]]);
  
    return { bcasrvmgr };
  });
  
module.exports = BCAServiceManagerModule;
