# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/polygon.json
export RPC_URL=$RPC_URL_POLYGON
export OWNER=$OWNER_POLYGON

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy