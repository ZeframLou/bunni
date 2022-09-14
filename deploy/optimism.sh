# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/optimism.json
export RPC_URL=$RPC_URL_OPTIMISM
export OWNER=$OWNER_OPTIMISM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy