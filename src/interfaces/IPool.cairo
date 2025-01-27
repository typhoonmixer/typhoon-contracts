use starknet::{ContractAddress};
#[starknet::interface]
pub trait IPool<TState> {
    fn processDeposit(ref self: TState, _from: ContractAddress, reward: bool, commitment: u256) -> (u256, Array<u256>);
    fn processWithdraw(ref self: TState, full_proof_with_hints: Span<felt252>);
    fn updateDay(ref self: TState);
    fn currentDay(self: @TState) -> u256;
    fn calculateReward(self: @TState, start_day: u256, days: u256) -> u256;
    fn factory(self: @TState)->ContractAddress;
    fn liquidityProviders(self: @TState, _day: u256) -> u256;
    fn rewardedLiquidityProviders(self: @TState, _day: u256) -> u256;
    fn withdrawsInDay(self: @TState, _day: u256) -> u256;
    fn token(self: @TState) -> ContractAddress;
    fn denomination(self: @TState) -> u256;
    fn withdrawFee(self: @TState) -> u256;
    fn isKnownRoot(self: @TState, _root: u256) -> bool;
    fn zeros(self: @TState, i: u32) -> u256;
    fn hashLeftRight(self: @TState, _left: u256, _right: u256) -> u256;
    fn getLastRoot(self: @TState) -> u256;
    fn isSpent(self: @TState, _nullifierHash: u256) -> bool;
    
}