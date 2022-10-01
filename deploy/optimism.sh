# load environment variables from .env
source .env

# set env variables
export ADDRESSES_FILE=./deployments/optimism.json
export OWNER=$OWNER_OPTIMISM

# load common utilities
. $(dirname $0)/common.sh

# deploy contracts
deploy optimism