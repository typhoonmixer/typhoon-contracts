use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use typhoon::interfaces::ITyphoon::{ITyphoonDispatcher, ITyphoonDispatcherTrait};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[cfg(test)]
#[test]
#[should_panic]
fn test_deposit_fail_wrong_length(){
    let contract_address = deploy_contract("Typhoon");

    let dispatcher = ITyphoonDispatcher { contract_address };

    let mut commitment: Array<u256> = ArrayTrait::<u256>::new();
    commitment.append(0);
    commitment.append(1);
    commitment.append(2);

    let mut pool: Array<ContractAddress> = ArrayTrait::<ContractAddress>::new();
    pool.append(0);
    pool.append(1);
    pool.append(2);
    pool.append(3);

    dispatcher.deposit(commitment.span(), pool.span(), false);
}

#[test]
#[should_panic]
fn test_deposit_fail_not_allowed_pool(){
    let contract_address = deploy_contract("Typhoon");

    let dispatcher = ITyphoonDispatcher { contract_address };

    let mut commitment: Array<u256> = ArrayTrait::<u256>::new();
    commitment.append(0);
    commitment.append(1);
    commitment.append(2);

    let mut pool: Array<ContractAddress> = ArrayTrait::<ContractAddress>::new();
    pool.append(0);
    pool.append(1);
    pool.append(2);

    dispatcher.deposit(commitment.span(), pool.span(), false);
}

#[test]
fn test_add_pool(){
    let contract_address = deploy_contract("Typhoon");

    let dispatcher = ITyphoonDispatcher { contract_address };

    let ta: felt252 = 0x123;
    let token_address: ContractAddress = ta.try_into().unwrap();


    dispatcher.addPool(token_address, 100000, 0);

    let ca: felt252 = 0x0;
    let comp_address: ContractAddress = ca.try_into().unwrap();

    assert!(dispatcher.getPool(token_address, 100000) == comp_address, "Is an invalid pool");
}