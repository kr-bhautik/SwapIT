import { ethers } from "hardhat";

async function main() {
    const SwapItContract = await ethers.getContractFactory('SwapIt');
    console.log("Deploying SwapIT contract...")
    const tx = await SwapItContract.deploy();
    console.log("Contract deployed at", await tx.getAddress());
}

main().then(() => console.log("Success")).catch((err) => console.log(err));