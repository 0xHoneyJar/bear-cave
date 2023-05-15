# THJ On-chain Games

Core Concepts:
- Gates
- Bundles


Core components:
- GameRegistry
- HoneyBox
- Gatekeeper
- HoneyJar NFT
- HoneyJar Portal

## Game Registry

Source of truth and authority within The HoneyJar Ecosystem. 
Contains the source of truth for Stage Times -- What are possible stages for gates to open
Game Contracts can have three states within the registry:
- Registered: Grants the contract `GAME_INSTANCE` permissions. (Must be manually revoked with `revokeRole`)
- Started: Grants `MINTER` permissions. for the NFTs within the ecosystem. 
- Stopped: Revokes `MINTER` permissions

##  HoneyBox

Contains all core business logic for THJ games. 
`MintConfig` specifies the number of claimable & mintable NFTS. 
    - _double check decimals for ERC price_

**Pre-req for a game(Only Game Admin)**
- Add list of ERC721 & ERC1155 Compatible NFTs to contract using `addBundle` (Returns bundleID)
- Add at least one gate to the gatekeeper, with the associated BundleId

**Starting a game (Only Game Admin)**
- Call `PuffPuffOut`: 
    - transfers all NFTs from the game_admin into the contract
    - starts gates within gatekeeper

**Minting HoneyJars (NFTs)**

Early Claim Period
- These are the earlier stages in `gameRegistry.stageTimes`. Players can either claim or mint early depending on their inclusion within a MerkleRoot.
- If a player is eligible to a claim, they can call `honeyBox.claim()` to claim their free HoneyJars
- If a player is eligible to mint before general mint, they can call `honeyBox.earlyMekHoneyJarWith[ETH|ERC20]`

General Mint Period
- After the last configured stage time: there are no restrictions on the general functions `honeyBox.earlyMekHoneyJarWith[ERC20|ETH]`
- The earlier claim /mint methods may still be called are still functional. 


## Gatekeeper

Maintains the logic and accounting for various gates per bundleId. There is no limit to the number of gates that can exist per game bundle. 

### Gate
- Maintains a MerkleRoot of eligible players for the particular gate. 
    - Each node in the Merkle Tree is `(playerAddress, amount)` where `amount` is the number of claimable items. 
- Gates also track the amount of HoneyJars claimed. This value can be used in the following two ways
    - `gate.maxClaimable == sum(merkleNode.amount)`: All players can claim the number of tokens allocated to them
    - `gate.maxClaimable < sum(merkleNode.amount)`: Claiming becomes FCFS where some players may not be able to claim .


## HoneyJar Portal

Modeled off of LayerZero ONFT, it contains the core business logic for the following:
- Moving the HoneyJar tokens across chains
- Sending THJ messages to the destination chain
When transfering a token to another chain, the token is **BURNED** on the source chain and re-minted on the destination chain. 
`HoneyJarPortal` contracts require the `BURNER` role within the GameRegistry

## Cross Chain Games

Contracts that need to exist on each chain:
- GameRegistry: Maybe sync from source chain?
- Gatekeeper: Maybe sync from source chain? 
- HoneyBox-lite: only reponsible for minting and tracking tokens 
- HoneyJar 

### Flow


Destination Chain:
- Deploy:
    - HoneyBox
    - Gatekeeper
    - GameRegistry
    - NFT
- Setup Deployment

Source chain: (ETH)
- `AddBundle`
- `PuffPuffPassOut`
- `startGatesForToken` 
    if xChain bundle --> HJP `startXChainGame()`
- honeybox.mint should not work. (bundle.isCrossChain);

Destination Chain: (ARB)
- HoneyBox.startGame() --> bundleConfig but no bundle
- GateKeeper: rcv StartGates for token.
- GameRegistry: startGame
- Players can call honeyBox.claim, earlyMint, mint on times. 
- Last mint: Chainlink VRF from bundleConfig 
- get winning tokenIds
- HJP --> send to honeyBox(source)

Source Chain (ETH):
- Store Winning TokenIds

WakeSleeper: ETH:
- Validate msg.sender is owner of token
- arb.honeybox.sign I AM OWNER. 
- eth.honeyBox.claim I AM OWNER --> send to msg.sender. 
