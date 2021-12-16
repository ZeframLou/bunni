build    :; dapp build
clean  :; dapp clean
test   :; dapp test
snapshot :; dapp snapshot
lint   :; npm run prettier

# install solc version
# example to install other versions: `make solc 0_8_2`
SOLC_VERSION := 0_7_6
solc:; nix-env -f https://github.com/dapphub/dapptools/archive/master.tar.gz -iA solc-static-versions.solc_${SOLC_VERSION}