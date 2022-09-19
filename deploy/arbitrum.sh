# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/arbitrum.json
export RPC_URL=$RPC_URL_ARBITRUM
export OWNER=$OWNER_ARBITRUM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy