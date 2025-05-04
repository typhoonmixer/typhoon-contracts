use starknet::ContractAddress;
use core::starknet::eth_address::EthAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use typhoon::interfaces::INoteAccount::{INoteAccountDispatcher, INoteAccountDispatcherTrait};

fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_add_note(){
    let contract_address = deploy_contract("NoteAccount");

    let address: felt252 = 0x1234567890123456789012345678901234567890;
    let pubKey: EthAddress = address.try_into().unwrap();

    let mut encryptedNote: Array<u256> = ArrayTrait::<u256>::new();
    encryptedNote.append(0);
    encryptedNote.append(1);
    encryptedNote.append(2);
    encryptedNote.append(3);
    encryptedNote.append(4);
    encryptedNote.append(5);
    encryptedNote.append(6);
    let msg_hash: u256 = 0x1234567890123456789012345678901234567890;
    let r: u256 = 0x1234567890123456789012345678901234567890;
    let s: u256 = 0x1234567890123456789012345678901234567890;
    let v: u32 = 27;
    let dispatcher = INoteAccountDispatcher { contract_address };
    dispatcher.addNote(pubKey, encryptedNote.span(), msg_hash, r, s, v);
}

#[test]
fn test_get_notes(){
    let contract_address = deploy_contract("NoteAccount");

    let address: felt252 = 0x1234567890123456789012345678901234567890;
    let pubKey: EthAddress = address.try_into().unwrap();

    let mut encryptedNote: Array<u256> = ArrayTrait::<u256>::new();
    encryptedNote.append(0);
    encryptedNote.append(1);
    encryptedNote.append(2);
    encryptedNote.append(3);
    encryptedNote.append(4);
    encryptedNote.append(5);
    encryptedNote.append(6);
    let msg_hash: u256 = 0x1234567890123456789012345678901234567890;
    let r: u256 = 0x1234567890123456789012345678901234567890;
    let s: u256 = 0x1234567890123456789012345678901234567890;
    let v: u32 = 27;

    let dispatcher = INoteAccountDispatcher { contract_address };
    dispatcher.addNote(pubKey, encryptedNote.span(), msg_hash, r, s, v);
    let notes = dispatcher.getNotes(pubKey);
    assert(*notes.at(0) == (0,1,2,3,4,5,6), 'Is an invalid result hash');
}

#[test]
fn test_update_notes(){
    let contract_address = deploy_contract("NoteAccount");

    let address: felt252 = 0x1234567890123456789012345678901234567890;
    let pubKey: EthAddress = address.try_into().unwrap();

    let mut encryptedNote: Array<u256> = ArrayTrait::<u256>::new();
    encryptedNote.append(0);
    encryptedNote.append(1);
    encryptedNote.append(2);
    encryptedNote.append(3);
    encryptedNote.append(4);
    encryptedNote.append(5);
    encryptedNote.append(6);
    let msg_hash: u256 = 0x1234567890123456789012345678901234567890;
    let r: u256 = 0x1234567890123456789012345678901234567890;
    let s: u256 = 0x1234567890123456789012345678901234567890;
    let v: u32 = 27;

    let dispatcher = INoteAccountDispatcher { contract_address };
    dispatcher.addNote(pubKey, encryptedNote.span(), msg_hash, r, s, v);
    let mut newNotes: Array<u256> = ArrayTrait::new();
    newNotes.append(7);
    newNotes.append(8);
    newNotes.append(9);
    newNotes.append(10);
    newNotes.append(11);
    newNotes.append(12);
    newNotes.append(13);

    let mut notes: Array<Span<u256>> = ArrayTrait::new();
    notes.append(encryptedNote.span());
    notes.append(newNotes.span());
    dispatcher.updateNotes(pubKey, msg_hash, r, s, v, notes.span());
    let notes = dispatcher.getNotes(pubKey);
    
    assert(*notes.at(0) == (0,1,2,3,4,5,6), 'Is an invalid result hash');
    assert(*notes.at(1) == (7,8,9,10,11,12,13), 'Is an invalid result hash');

}