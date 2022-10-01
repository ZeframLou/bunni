# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/goerli.json
export OWNER=$OWNER_GOERLI

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy goerli