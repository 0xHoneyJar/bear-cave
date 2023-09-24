import {MerkleTree} from 'merkletreejs';
import keccak256 from "keccak256";
import { ethers } from "ethers";


// Define the data you want to include in the Merkle tree
const data = [
  { address: '0xF951bA8107D7BF63733188E64D7E07bD27b46Af7', amount: 100 },
  { address: '0x40495A781095932e2FC8dccA69F5e358711Fdd41', amount: 0 },
];


function generateProofs(nodes) {
    const leaves = nodes.map((node) => {
        return keccak256(ethers.solidityPacked(["address", "uint32"], [node.address, node.amount]));
    });

    const tree = new MerkleTree(leaves, keccak256, {
        sortPairs: true,
    });

    const root = tree.getHexRoot();
    console.log(tree.verify(tree.getHexProof(leaves[0]), leaves[0], root));
    console.log("Root: ",  tree.getHexRoot());
    console.log("Leaves: ", tree.getHexLeaves());
    console.log("Proof 1: ", tree.getHexProof(leaves[0]));

}

// Now you can call functions of the contract

generateProofs(data);



