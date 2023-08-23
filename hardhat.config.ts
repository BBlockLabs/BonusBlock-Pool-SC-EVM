import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const SEPOLIA_PRIVATE_KEY = "CHANGEME";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  etherscan: {
    apiKey: "CHANGEME",
  },
  networks: {
    sepolia: {
      url: `https://rpc.sepolia.org`,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
  },
};

export default config;
