ADDRESSES_FILE=${ADDRESSES_FILE:-./deployments/output.json}

deploy() {
	NETWORK=$1

	RAW_RETURN_DATA=$(forge script script/Deploy.s.sol:Deploy -f $NETWORK -vvvv --json --silent --broadcast --verify --skip-simulation)
	RETURN_DATA=$(echo $RAW_RETURN_DATA | jq -r '.returns' 2> /dev/null)

	hub=$(echo $RETURN_DATA | jq -r '.hub.value')
	lens=$(echo $RETURN_DATA | jq -r '.lens.value')
	migrator=$(echo $RETURN_DATA | jq -r '.migrator.value')

	saveContract "BunniHub" "$hub"
	saveContract "BunniLens" "$lens"
	saveContract "BunniMigrator" "$migrator"
}

saveContract() {
	# create an empty json if it does not exist
	if [[ ! -e $ADDRESSES_FILE ]]; then
		echo "{}" >"$ADDRESSES_FILE"
	fi
	result=$(cat "$ADDRESSES_FILE" | jq -r ". + {\"$1\": \"$2\"}")
	printf %s "$result" >"$ADDRESSES_FILE"
}