import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  paths: {
    artifacts: "./artifacts",
    cache: "./cache-hardhat",
    sources: "./src",
    tests: "./test"
  }
};

export default config;
