import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "solidity-coverage";
import dotenv from "dotenv";
dotenv.config();

const INFURA_API_KEY = process.env.INFURA_API_KEY ?? 'missing';
const POLYGON_PRIVATE_KEY = process.env.POLYGON_PRIVATE_KEY ?? '1234567890123456789012345678901234567890123456789012345678901234';
const AMOY_PRIVATE_KEY = process.env.AMOY_PRIVATE_KEY ?? '1234567890123456789012345678901234567890123456789012345678901234';


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
