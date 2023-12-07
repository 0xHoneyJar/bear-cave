# Operations Runbook

This doc there to walk through the deployment + maintenance/operation of the THJ ecosystem. 

**Key points**
- [thj.sh](thj.sh) has been built to be a utility belt for the THJ ecosystem
    - Append `--broadcast` to publish the txns to the chain
- There are subfolders (like [gen1](gen1/), [gen2](gen2/), [gen3](gen3/)) that contain configuration for each deployment and chain
- Commands will be given from the root directory of the 

## Environment Setup
- Packages:
    - `forge`
    - `jq`
- `.env`: see [.env.example](../.env.example)
    - Need RPC urls for each chain



## Setup Process

**READ THE SCRIPTS SO YOU KNOW WHAT THEY'RE DOING**

*Note*: Replace mainnet in the examples with the chainName. We will refer to the other chain outside of mainnet, to be the `MintChain`

1. Create VRF Subscription on the MintChain  --  https://docs.chain.link/vrf/v2/subscription/supported-networks
1. - Populate configs under the appropriate generation folder: `script/genN` in the format `config.<chainname>.json`
    - Ensure the `mintChainId` & `assetChainId` are correct. Generally `assetChainId` = 1 for ETH mainnet
1. Populate [03_SetGates.s.sol](03_SetGates.s.sol), with the correct merkle roots and claimable values



### Step 1: [Deploy](00_Deploy.s.sol)
*As you deploy the contracts, update the `config.json` w/ the deployment addresses

For both mainnet & the destination chain deploy the contracts as follows: 

1. Deploy Gatekeeper & GameRegistry: ```./script/thj.sh -n [mainnet|mintChain] deploy1```

1. Deploy HoneyJar NFT: ```./script/thj.sh -n [mainnet|mintChain] deploy2```

1. Deploy HibernationDen ```./script/thj.sh -n [mainnet|mintChain] deploy3```
    -- Add the HibernationDen to the VRF subscribers list on the mintChain

1. Deploy HoneyJarPortal: ```./script/thj.sh -n [mainnet|mintChain] deploy4```

### Step 2: [Configure](01_ConfigureGame.s.sol)

For both chains:
```
./script/thj.sh -n mainnet config
./script/thj.sh -n mintChain config

```
1. Calls `hibernationDen.initialize(vrfConfig, mintConfig);`,
1. Registers game w/ GameRegistry -- so it can have minting permissions
1. Grants portal minting/burning permissions on the NFT

Then for both chains:
```
./script/thj.sh -n mainnet -n2 mintChain config-portals
./script/thj.sh -n mintChain -n2 mainnet config-portals
```
1. Sets up the portal contract on the other chain to be the validate destination for message passing.
1. Sets minGas requirements for `SEND_NFT`, `START_GAME`, & `SET_FERMENTED_JARS`
1. Sets up max batchsize for xfering winning NFTs

### Step 3: [BundleTokens](02_BundleTokens.s.sol)

Only on Mainnet:
```
./script/thj.sh -n mainnet addBundle
```
1. Registers bundle NFTs to the Hibernation Den
1. Inserts record of checkpoints

*Update BundleID in config.json once complete*


### Step 4: [SetGates](03_SetGates.s.sol)

Only on MintChainId
```
./script/thj.sh -n mintChain setGates
```
1. Adds gates to the gatekeeper on the mintChain


### Step 5: [StartGame](04_StartGame.s.sol)

On both Chains:
```
./script/thj.sh -n mainnet startGame
./script/thj.sh -n mintChain startGame
```
1. Starts starts game in gameRegistry -- Can mint NFTs
1. Sets the portal in the hibernationDen

### Step 6: PuffPuffPassOut

Admin mint before starting the game

The following actions are done from the `GAME_ADMIN` multisig that owns the assets listed in the bundle

Call `hibernationDen.puffPuffPassOut(bundleId)` -- BundleId should be 0

If everything worked correctly the following should have happened:
1. Assets/NFTs were transferred from the MS to the HibernationDen contract
1. Gates were start at the time of calling the method -- Gates that open with a time delay use the time of starting the game as the initial offset. 
1. For Xchain games, sends a message to the portal containing the following:
    -   `mintChainId`, `bundleId`, `sleeperCount` (number of NFTs in the bundle), `checkpoints` (from the configuration)

## Common Operations

### Adding NFTs to the party after games have begun

**Modify the script [06_AddToParty.s.sol](06_AddToParty.s.sol) to contain the right values for the NFT being added

On mainnet, the NFT addresses will be the be actual addresses with the optionality to initiate a transfer into the den. 
```
./script/thj.sh -n mainnet addToParty
```
On the mintChain, the NFT addresses will be address(0):
```
./script/thj.sh -n mintChain addToParty
```


### Sending fermernted Jars payload from mintChaind --> mainnet

### Debugging LayerZero Messaging








