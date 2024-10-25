import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "solidity-coverage";

const { vars } = require("hardhat/config");
const INFURA_API_KEY = vars.get("INFURA_API_KEY");
const POLYGON_PRIVATE_KEY = vars.get("POLYGON_PRIVATE_KEY");
const AMOY_PRIVATE_KEY = vars.get("AMOY_PRIVATE_KEY");


const config: HardhatUserConfig = {
  solidity: {
     version: "0.8.24",
     settings: {
       optimizer: {
         enabled: true,
         runs: 1000,
       },
    },
  },
  networks: {
      polygon: {
          url: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
          accounts: [POLYGON_PRIVATE_KEY]
      },
      amoy: {
          url: `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
          accounts: [AMOY_PRIVATE_KEY]
      }
  }
};

export default config;
