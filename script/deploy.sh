source .env

forge script script/DeployMainnet.s.sol:DeployMainnet --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow -vvvvv \
--broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY \ 
# --resume # uncomment to resume from a previous deployment