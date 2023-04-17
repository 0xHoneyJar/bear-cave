source .env.testnet

forge script script/00_DeployTestnet.s.sol:DeployScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow -vvvvv \
# --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY \ # uncomment to broadcast to the network
# --resume # uncomment to resume from a previous deployment
