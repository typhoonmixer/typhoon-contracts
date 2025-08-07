use core::starknet::eth_address::EthAddress;
use starknet::{ClassHash};
use starknet::{ContractAddress};


#[starknet::interface]
pub trait INoteAccount<TContractState> {
    fn addNote(ref self: TContractState, pubKey: EthAddress, encryptedNote: Span<u256>, msg_hash: u256, r: u256, s: u256, v: u32);
    fn updateNotes(ref self: TContractState,pubKey: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32 ,noteIndex: u256);
    fn getNotes(self: @TContractState, pubKey: EthAddress) -> Array<Array<u256>>;
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn setOwner(ref self: TContractState, new_owner: ContractAddress);
    fn getOwner(self: @TContractState) -> ContractAddress;
}
