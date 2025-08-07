import { RpcProvider, Account, Contract, json, stark, uint256, shortString, CallData, AccountInterface, constants } from 'starknet';
import * as fs from 'fs';
const verifierSierra = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Groth16VerifierBN254.contract_class.json', 'utf8')
);
const verifierCasm = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Groth16VerifierBN254.compiled_contract_class.json', 'utf8')
);
const hasherSierra = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Hasher.contract_class.json', 'utf8')
)
const hasherCasm = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Hasher.compiled_contract_class.json', 'utf8')
);
const typhoonSierra = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Typhoon.contract_class.json', 'utf8')
)
const typhoonCasm = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Typhoon.compiled_contract_class.json', 'utf8')
);
const poolSierra = JSON.parse(  
    fs.readFileSync('../target/dev/typhoon_Pool.contract_class.json', 'utf8')
);
const poolCasm = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_Pool.compiled_contract_class.json', 'utf8')
);
const noteAccountSierra = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_NoteAccount.contract_class.json', 'utf8')
);
const noteAccountCasm = JSON.parse(
    fs.readFileSync('../target/dev/typhoon_NoteAccount.compiled_contract_class.json', 'utf8')
);

import dotenv from 'dotenv'

dotenv.config({ path: '../.env' })

const provider = new RpcProvider({ nodeUrl: "https://starknet-mainnet.public.blastapi.io/rpc/v0_8"});
const accAddress = "0x03f2039a5c1742f8d90985eabaddf691090176511ebe9d3bcd042b1914918e64"
const ethAddress = "0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7"
const strkAddress = "0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d"
const tokens = [ethAddress, strkAddress]
console.log("priv key ", process.env.PRIVATE_KEY)
const account = new Account(provider, accAddress, process.env.PRIVATE_KEY);


async function deploy() {
    // const typhoonAddress = "0x5e82f6558c20cbb25cf1fc9175021d3172123a22d5af70bebb0a13866985609"

    // const { abi: typhoonAbi } = await provider.getClassAt(typhoonAddress);
    // const typhoon = new Contract(typhoonAbi, typhoonAddress, account);

    // let isRoot = await typhoon.isKnownRoot(BigInt("9662676834302638852743737306812847358206667280625371298355741299892273837783"))
    // return isRoot
    // return '0x'+pool.toString(16)

    // const verifierAddress = "0x4ee1ebf59714f2160bed90bb4206d12eed2cfa524d27e3a906d7c212fc3623e"

    // const { abi: verifierAbi } = await provider.getClassAt(verifierAddress);
    // const verifier = new Contract(verifierAbi, verifierAddress, account);
    // let verification = await verifier.verify_groth16_proof_bn254(callData)
    // return verification

    const noteCallData = new CallData(noteAccountSierra.abi)
    const noteConstructor = noteCallData.compile('constructor', {
        owner: accAddress,
    });

    let noteAccountResponse = await account.declareAndDeploy({
        contract: noteAccountSierra,
        casm: noteAccountCasm,
        constructorCalldata: noteConstructor
    });
    await provider.waitForTransaction(noteAccountResponse.deploy.transaction_hash);
    console.log("note account deployed at ", noteAccountResponse.deploy.contract_address)

    console.log("deploying verifier...")

    let verifierResponse = await account.declareAndDeploy({
        contract: verifierSierra,
        casm: verifierCasm,
    });
    await provider.waitForTransaction(verifierResponse.deploy.transaction_hash);
    console.log("verifier deployed at ", verifierResponse.deploy.contract_address)


    console.log("deploying hasher...")
    let hasherResponse = await account.declareAndDeploy({
        contract: hasherSierra,
        casm: hasherCasm,
    });
    await provider.waitForTransaction(verifierResponse.deploy.transaction_hash);
    console.log("hasher deployed at ", hasherResponse.deploy.contract_address)


    // console.log("declaring pool...")
    // let declaredPool = await account.declare({
    //     contract: poolSierra,
    //     casm: poolCasm
    // })

    // await provider.waitForTransaction(declaredPool.transaction_hash);

    const typhoonCallData = new CallData(typhoonSierra.abi)
    const typhoonConstructor = typhoonCallData.compile('constructor', {
        owner: accAddress,
        _hasher: hasherResponse.deploy.contract_address,
        _verifier: verifierResponse.deploy.contract_address,
        _poolClassHash: "0x041b7800cc74dbfc96bbbbacbc55b90e2ce2b0543aadc0603ceb12f88ba5fa65",
    });

    console.log("deploying typhoon...")
    let typhoonResponse = await account.declareAndDeploy({
        contract: typhoonSierra,
        casm: typhoonCasm,
        constructorCalldata: typhoonConstructor
    })
    await provider.waitForTransaction(typhoonResponse.deploy.transaction_hash);
    console.log("typhoon deployed at ", typhoonResponse.deploy.contract_address)

    // const { abi: typhoonAbi } = await provider.getClassAt(typhoonResponse.deploy.contract_address);
    // if (typhoonAbi === undefined) {
    //     throw new Error('no abi.');
    // }
    // const typhoon = new Contract(typhoonAbi, typhoonResponse.deploy.contract_address, provider);
    // typhoon.connect(account)



    // let baseDenomination = BigInt('1' + '0'.repeat(16))

    // let now = new Date();
    // now.setUTCHours(0, 0, 0, 0);
    // let currentDay = Math.floor(now.getTime() / 1000);

    // console.log("deploying and adding pools...")
    // for (let i = 0; i < 2; i++) {
    //     for (let j = 0; j < 5; j++) {
    //         const call = typhoon.populate('addPool', [tokens[i], baseDenomination * BigInt(10 ** j), currentDay, BigInt(500)]);
    //         const res = await typhoon.addPool(call.calldata);

    //         await provider.waitForTransaction(res.transaction_hash);
    //     }
    // }
    // console.log("pools deployed and added")
    console.log("Typhoon address: ", typhoonResponse.deploy.contract_address)
    return [typhoonResponse.deploy.contract_address, verifierResponse.deploy.contract_address, hasherResponse.deploy.contract_address, noteAccountResponse.deploy.contract_address];
}

deploy().then((typhoon) => {
    // console.log(typhoon)
    const jsonString = JSON.stringify({ "typhoon": typhoon[0], "verifier": typhoon[1], "hasher": typhoon[2], "noteAccount": typhoon[3] }, null, 2); // The third argument adds indentation for readability

    // Write the JSON string to a file
    fs.writeFile('typhoon-mainnet.json', jsonString, 'utf8', (err) => {
        if (err) {
            console.error('An error occurred while writing JSON Object to File:', err);
        } else {
            console.log('JSON file has been saved.');
        }
    });
})