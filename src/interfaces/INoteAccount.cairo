use core::starknet::eth_address::EthAddress;

#[starknet::interface]
pub trait INoteAccount<TContractState> {
    fn addNote(ref self: TContractState, pubKey: EthAddress, encryptedNote: Span<u256>, msg_hash: u256, r: u256, s: u256, v: u32);
    fn updateNotes(ref self: TContractState,pubKey: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32 ,newNotes: Span<Span<u256>>);
    fn getNotes(self: @TContractState, pubKey: EthAddress) -> Array<(u256, u256, u256, u256, u256, u256, u256)>;
}
