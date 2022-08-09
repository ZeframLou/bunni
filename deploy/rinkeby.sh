# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/rinkeby.json
export RPC_URL=$RPC_URL_RINKEBY

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
bunni_hub_address=$(deploy BunniHub $UNIV3_FACTORY $WETH_RINKEBY $PROTOCOL_FEE)
echo "BunniHub=$bunni_hub_address"

bunni_lens_address=$(deploy BunniLens $bunni_hub_address)
echo "BunniLens=$bunni_lens_address"

bunni_migrator_address=$(deploy BunniMigrator $bunni_hub_address $WETH_RINKEBY)
echo "BunniMigrator=$bunni_migrator_address"