// import "hardhat-docgen"; // TODO : Error with vue for now
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import dotenv from "dotenv";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";
import fs from "fs";
import "hardhat-preprocessor";
import { HardhatUserConfig } from "hardhat/config";
import "@foundry-rs/hardhat-forge";

dotenv.config();

/**
 * Get the remappings from the remappings.txt file
 * @returns 
 */
function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
const config: HardhatUserConfig = {
  solidity: {
    settings: {
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
    compilers: [
      {
        version: "0.8.20",
        settings: {
          viaIR: true, // Gain a lot on contract size, performance impact ?
          optimizer: {
            enabled: true,
            runs: 100000,
            details: {
              peephole: true,
              inliner: true,
              jumpdestRemover: true,
              deduplicate: true,
              orderLiterals: true,
              constantOptimizer: true,
              cse: true,
              yul: true,
            },
          },
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    cache: "./cache_hardhat",
    artifacts: "./artifacts",
  },
  compilerOptions: {
    target: "es2018",
    module: "commonjs",
    strict: true,
    esModuleInterop: true,
    outDir: "dist",
    resolveJsonModule: true,
  },
  networks: {
    mumbai: {
      url: process.env.MUMBAI_PROVIDER,
      accounts: [process.env.SYBEL_DEPLOY_PRIV_KEY],
    },
    polygon: {
      url: process.env.POLYGON_PROVIDER,
      accounts: [process.env.FRAK_DEPLOY_PRIV_KEY],
    },
    goerli: {
      url: process.env.GOERLI_PROVIDER,
      accounts: [process.env.FRAK_DEPLOY_PRIV_KEY],
    },
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.POLYGON_SCAN_API_KEY,
      polygon: process.env.POLYGON_SCAN_API_KEY,
      goerli: process.env.ETHER_SCAN_API_KEY,
    },
  },
  include: ["./scripts", "./test", "./typechain-types"],
  files: ["./hardhat.config.ts"],
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
};

export default config;