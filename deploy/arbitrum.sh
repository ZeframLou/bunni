# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/arbitrum.json
export OWNER=$OWNER_ARBITRUM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy arbitrum