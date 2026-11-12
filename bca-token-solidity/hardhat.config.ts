import { defineConfig } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import "dotenv/config";

const INFURA_API_KEY = process.env.INFURA_API_KEY ?? 'missing';
const POLYGON_PRIVATE_KEY = process.env.POLYGON_PRIVATE_KEY ?? '0x1234567890123456789012345678901234567890123456789012345678901234';
const AMOY_PRIVATE_KEY = process.env.AMOY_PRIVATE_KEY ?? '0x1234567890123456789012345678901234567890123456789012345678901234';

export default defineConfig({
  plugins: [hardhatToolboxMochaEthers],
  test: {
    mocha: {
      timeout: 40000,
    },
  },
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
      type: "http",
      url: `https://polygon-mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [POLYGON_PRIVATE_KEY],
    },
    amoy: {
      type: "http",
      url: `https://polygon-amoy.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [AMOY_PRIVATE_KEY],
    },
  },
});
