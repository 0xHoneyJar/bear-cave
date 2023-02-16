# bears

idk bears

## featoors

-   Creates bear cave with `maxHoneycomb`
    -   erc1155 address is the openseaStoreToken: `0x495f947276749Ce646f68AC8c248420045cb7b5e` on Mainnet
-   Deposit an bongBear (erc1155 token) into BearCave by calling `hibernateBear(_bearId)`
-   Anyone can call `mekHoney(_bearId)` to create NFTs.
    -   honeycomv is stored in `honeyJar` for each bear
    -   honeycomb can be minted in paymentToken (ERC20) or ETH
-   upon final honeycomb mint, `findSpecialHoney(bearId)` will be called
    -   makes a call to chainlink VRF
    -   this will find the honeyId that will bring the bear out of cave.
    -   bear lazy and want to sleep
-   owner of specialHoney can call `wakeBear` to take bear from cave and put in own wallet.
-   Gatekeepooor
    -   keeper of the gates

## Claimooorrr restrictions

_The lower the restricshun on this list, the more specific it is_

-   `mintConfig.maxhoneycomb`: the maximum number of honeycombs that can be minted.
    -   Players can mint all the honeycombs before you can claim yours. RIP
-   `mintConig.maxClaimableHoneycomb`: max claims per bear.
-   `gatekeeper[tokenId][gate].maxClaimable` max claims per gate. i.e.
    -   there could be 420 people that qualify for the gate, but only 42 available claims.

## Spec

-   BongBears are Tokens of the OpenSea Shared Storefront collection: https://etherscan.io/token/0x495f947276749ce646f68ac8c248420045cb7b5e
    -   Example Wartull Token: https://etherscan.io/token/0x495f947276749ce646f68ac8c248420045cb7b5e?a=66075445032688988859229341194671037535804503065310441849644897976489592487937
    -   Token ID: 66075445032688988859229341194671037535804503065310441849644897976489592487937
    -   wtf
