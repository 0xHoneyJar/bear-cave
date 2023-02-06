# bears

idk bears

## featoors

-   Creates bear cave with `maxHoney`, and `sleepTime` params
    -   erc1155 address is the openseaStoreToken: `0x495f947276749Ce646f68AC8c248420045cb7b5e` on Mainnet
-   Deposit an bongBear (erc1155 token) into BearCave by calling `hibernateBear(_bearId)`
-   Anyone can call `mekHoney(_bearId)` to create NFTs.
    -   Honey is stored in `honeyJar` for each bear
-   when bear is done sleeping, owner can call `findSpecialHoney(bearId)`
    -   this will find the honeyId that will bring the bear out of cave.
    -   bear lazy and want to sleep
-   owner of specialHoney can call `wakeBear` to take bear from cave and put in own wallet.

## Spec

-   BongBears are Tokens of the OpenSea Shared Storefront collection: https://etherscan.io/token/0x495f947276749ce646f68ac8c248420045cb7b5e
    -   Example Wartull Token: https://etherscan.io/token/0x495f947276749ce646f68ac8c248420045cb7b5e?a=66075445032688988859229341194671037535804503065310441849644897976489592487937
    -   Token ID: 66075445032688988859229341194671037535804503065310441849644897976489592487937
-   To consider: What happens when a bear wakes up? How do we clean up data structures?
-   HeadClown deposit bong bear nft into smart contract. Smart contract can generate 10k nfts.
    -   Ideally SC splits bong bear into 10k unique nfts but automated.
    -   Wen a monkey brain mints nft they receive nft. This is tradeable on secondary markets. Then when all nfts are minted then a random nft ID is selected. Whichever wallet holds the nft with the winning ID will receive the bong bear
-   nfts apes receive should not be 1155 they shud be erc721
-   should launch on eth main net. Ok if buy currency is only ohm.
