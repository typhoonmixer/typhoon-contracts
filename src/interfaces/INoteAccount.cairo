#[starknet::interface]
pub trait INoteAccount<TContractState> {
    fn addNote(ref self: TContractState, pubKey: u256, encryptedNote: Span<felt252>);
    fn updateNotes(ref self: TContractState,pubKey: u256 ,newNotes: Array<(u256, u256, u256, u256, u256, u256, u256)>);
    fn getNotes(self: @TContractState, pubKey: u256) -> Array<(u256, u256, u256, u256, u256, u256, u256)>;
}
