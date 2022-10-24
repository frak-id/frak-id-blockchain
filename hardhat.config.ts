// import "hardhat-docgen"; // TODO : Error with vue for now
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import dotenv from "dotenv";
import "hardhat-abi-exporter";
import "hardhat-contract-sizer";

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
export default {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              orderLiterals: true,
              deduplicate: true,
              cse: true,
              constantOptimizer: true,
            },
          },
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  docgen: {
    path: "./docs",
    clear: true,
    runOnCompile: true,
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
  },
  etherscan: {
    apiKey: process.env.POLYGON_SCAN_API_KEY,
  },
  contractSizer: {
    runOnCompile: true,
  },
  include: ["./scripts", "./test", "./typechain-types"],
  files: ["./hardhat.config.ts"],
  typechain: {
    outDir: "./types",
  },
  gasReporter: {
    currency: "EUR",
    token: "MATIC",
    gasPriceApi: "https://api.polygonscan.com/api?module=proxy&action=eth_gasPrice",
    enabled: false,
    excludeContracts: [],
    src: "./contracts",
    coinmarketcap: process.env.COIN_MARKET_CAP_API_KEY,
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    format: "json",
    pretty: false,
  },
};
