use starknet::{ContractAddress};

#[starknet::interface]
pub trait ITyphoon<TContractState> {
    fn deposit(ref self: TContractState, _commitment: Array<u256>, _pool: Array<ContractAddress>, _reward: bool);
    fn withdraw(ref self: TContractState, full_proof_with_hints: Span<felt252>, pool: ContractAddress);
    fn getPool(
        self: @TContractState, _token: ContractAddress, _denomination: u256,
    ) -> ContractAddress;
    
    
    
    fn addPool(
        ref self: TContractState,
        _token: ContractAddress,
        _denomination: u256,
        _day: u256,
        _fee: u256
    );
    
    fn verifier(self: @TContractState) -> ContractAddress;
    fn hasher(self: @TContractState) -> ContractAddress;
    fn setPoolFee(ref self: TContractState, _pool: ContractAddress, _fee: u256);
    fn withdrawPoolProfit(ref self: TContractState, _pool: ContractAddress, _recipient: ContractAddress, _amount: u256);
}
