source .env

forge script script/01_BundleTokens.s.sol:BundleTokens --rpc-url $RPC_URL --private-key $PRIVATE_KEY --slow -vvvvv \
--broadcast \ # uncomment to broadcast to the network
# --resume # uncomment to resume from a previous deployment