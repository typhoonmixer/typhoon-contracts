import dotenv from 'dotenv'
import { RpcProvider, Account, Contract, json, stark, uint256, shortString, CallData, AccountInterface, constants, cairo } from 'starknet';
import * as fs from 'fs';
dotenv.config({ path: '../.env' })

const calldata = JSON.parse(
    fs.readFileSync('./calldata.json', 'utf8')
);

const provider = new RpcProvider({ nodeUrl: "https://starknet-sepolia.public.blastapi.io/rpc/v0_8"});
// const account = new Account(provider, accAddress, process.env.PRIVATE_KEY);

async function test(){
    const { abi: verifierAbi } = await provider.getClassAt("0x1ecfa02917589df3480354bd8e0be7c19c68462493fe52cb3ce396dc1e2019a");
    const verifierContract = new Contract(verifierAbi, "0x1ecfa02917589df3480354bd8e0be7c19c68462493fe52cb3ce396dc1e2019a", provider);

    const pubin = await verifierContract.verify_groth16_proof_bn254(calldata);
    return pubin
}

test().then((pub) => {
    console.log(pub)
    console.log(calldata.length)
})