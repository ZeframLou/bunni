# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/mainnet.json
export OWNER=$OWNER_MAINNET

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy mainnet