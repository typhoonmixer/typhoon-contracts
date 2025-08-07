use starknet::{ContractAddress};
use starknet::{ClassHash};

#[starknet::interface]
pub trait ITyphoon<TContractState> {
    fn deposit(ref self: TContractState, _commitment: u256, _pool: ContractAddress, _reward: bool);
    fn withdraw(ref self: TContractState, full_proof_with_hints: Span<felt252>);
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
    fn owner(self: @TContractState) -> ContractAddress;
    fn setOwner(ref self: TContractState, _new_owner: ContractAddress);
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
    fn getTokensByPool(self: @TContractState, token: ContractAddress) -> Array<ContractAddress>;
    fn upgradePools(ref self: TContractState, new_class_hash: ClassHash, token: ContractAddress);
}
