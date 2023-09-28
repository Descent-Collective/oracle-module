import * as env from 'env-var';
import * as dotenv from 'dotenv';

dotenv.config();

export default {
  rpcs: {
    ethereum: {
      mainnet: env.get('ETHEREUM_MAINNET_RPC').required().asString(),
      testnet: env.get('ETHEREUM_TESTNET_RPC').required().asString(),
    },
    base: {
      mainnet: env.get('BASE_MAINNET_RPC').required().asString(),
      testnet: env.get('BASE_TESTNET_RPC').required().asString(),
    },
  },
  privateKey: {
    mainnet: env.get('MAINNET_PRIVATE_KEY').required().asString(),
    testnet: env.get('TESTNET_PRIVATE_KEY').required().asString(),
  },
  etherscan: {
    apiKey: env.get('ETHERSCAN_API_KEY').asString(),
  },
};
