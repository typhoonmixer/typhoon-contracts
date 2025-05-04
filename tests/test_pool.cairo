use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use typhoon::interfaces::IPool::{IPoolDispatcher};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[cfg(test)]
#[test]
fn test_process_deposit(){
    let contract_address = deploy_contract("Pool");
    let dispatcher = IPoolDispatcher { contract_address };

    
}