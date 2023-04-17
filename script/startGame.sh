source .env
source .env.goerli

forge script script/03_StartGame.s.sol:StartGame --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvv