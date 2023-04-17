include .env

.PHONEY: setupGoerli addBundle setGates startGame


define setup_env
	$(eval ENV_FILE := .env.$(1))
	@echo " - setup env $(ENV_FILE)"
	$(eval include .env.$(1))
	$(eval export sed 's/=.*//' .env.$(1))
endef

# Call `make {command} --broadcast` to send to the chain

setupGoerli:
	$(call setup_env,goerli)

addBundle: setupGoerli
	forge script script/01_BundleTokens.s.sol:BundleTokens --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvvv 


setGates: setupGoerli
	forge script script/02_SetGates.s.sol:SetGates --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvv $@


startGame: setupGoerli
	forge script script/03_StartGame.s.sol:StartGame --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --slow -vvvv $0
