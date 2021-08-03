import "@nomiclabs/hardhat-waffle";
import "solidity-coverage";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-solhint";
import "hardhat-spdx-license-identifier";
import "hardhat-docgen";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";
import "@typechain/hardhat";

import { HardhatUserConfig } from "hardhat/config";

let secret;

try {
  secret = require("./secret.json");
} catch {
  secret = {
    account: "",
    mnemonic: ""
  };
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  namedAccounts: {
    deployer: {
      default: 1
    }
  },
  paths: {
    sources: "./contracts"
  },
  networks: {
    mainnet: {
      url:
        "https://eth-mainnet.alchemyapi.io/v2/pvGDp1uf8J7QZ7MXpLhYs_SnMnsE0TY5",
      chainId: 1,
      from: secret.account,
      accounts: {
        mnemonic: secret.mnemonic
      },
      gas: "auto",
      gasPrice: 84.0000001e9
    },
    hardhat: {
      /*forking: {
        url:
          "https://eth-mainnet.alchemyapi.io/v2/pvGDp1uf8J7QZ7MXpLhYs_SnMnsE0TY5"
      }*/
    }
  },
  spdxLicenseIdentifier: {
    runOnCompile: true
  },
  docgen: {
    except: [],
    clear: true,
    runOnCompile: false
  },
  mocha: {
    timeout: 60000
  },
  etherscan: {
    apiKey: "SCTNNP3MJK18WV84QIX6WPGMWIS8H1J9W7"
  },
  gasReporter: {
    currency: "USD",
    coinmarketcap: "b0c64afd-6aca-4201-8779-db8dc03e9793"
  },
  typechain: {
    target: "ethers-v5"
  }
};

export default config;
