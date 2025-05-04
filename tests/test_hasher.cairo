use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use typhoon::interfaces::IHasher::{IHasherDispatcher, IHasherDispatcherTrait};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[cfg(test)]
#[test]
fn test_hasher() {
    let contract_address = deploy_contract("Hasher");

    let k: u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    let mut ins: [u256; 2] = [
    8446592859352799428420270221449902464741693648963397251242447530457567083492,
    1064796367193003797175961162477173481551615790032213185848276823815288302804];

    

    let dispatcher = IHasherDispatcher { contract_address };

    let r = dispatcher.MiMC5Sponge(ins,k);
    assert(r == 20314672684573017317920629862504501369327185477692989173621274148638071089191, 'Is an invalid result hash');
}
