use starknet::{ContractAddress};
#[starknet::interface]
pub trait IPool<TState> {
    fn processDeposit(ref self: TState, _from: ContractAddress, commitment: u256) -> (Array<Array<u256>>,Array<u256>, u256);
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
    fn isKnownDD(self: @TState, _dd: u256) -> bool;
    fn zeros(self: @TState, i: u32) -> u256;
    fn hashLeftRight(self: @TState, _left: u256, _right: u256) -> u256;
    fn getLastRoot(self: @TState) -> u256;
    fn isSpent(self: @TState, _nullifierHash: u256) -> bool;
    fn setWithdrawFee(ref self: TState, _fee: u256);
    fn withdrawProfit(ref self: TState, _recipient: ContractAddress, _amount: u256);
    fn getProfit(self: @TState) -> u256;
    fn getCount(self: @TState) -> u256;
    fn getLeafAt(self: @TState, lv: u256, ll: u256) -> u256;
}