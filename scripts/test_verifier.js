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
    const { abi: verifierAbi } = await provider.getClassAt("0x83157f469d0ab0d9cbbad6c76626407617da9aaa4faecf580f01391081cb02");
    const verifierContract = new Contract(verifierAbi, "0x83157f469d0ab0d9cbbad6c76626407617da9aaa4faecf580f01391081cb02", provider);

    const pubin = await verifierContract.verify_groth16_proof_bn254(calldata);
    return pubin
}

test().then((pub) => {
    console.log(pub)
    console.log(calldata.length)
})