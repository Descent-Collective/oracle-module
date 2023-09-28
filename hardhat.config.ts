import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import env from './config/env';

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.18',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {},
    ethereum_mainnet: {
      url: env.rpcs.ethereum.mainnet,
      accounts: [env.privateKey.mainnet],
    },
    ethereum_testnet: {
      url: env.rpcs.ethereum.testnet,
      accounts: [env.privateKey.testnet],
    },
    base_mainnet: {
      url: env.rpcs.base.mainnet,
      accounts: [env.privateKey.mainnet],
    },
    base_testnet: {
      url: env.rpcs.base.testnet,
      accounts: [env.privateKey.testnet],
    },
  },
  etherscan: {
    apiKey: env.etherscan.apiKey,
  },
};

export default config;
