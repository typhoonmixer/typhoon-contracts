#[starknet::contract]
pub mod Typhoon {
    use core::circuit::CircuitInputs;
    use core::num::traits::Zero;
    use core::pedersen::PedersenTrait;
    use starknet::event::EventEmitter;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ClassHash, ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
        get_contract_address, syscalls,
    };
    use typhoon::interfaces::IHasher::IHasherDispatcher;
    use typhoon::interfaces::IPool::IPoolDispatcher;
    use typhoon::interfaces::ITyphoon::ITyphoon;
    use typhoon::verifier::groth16_verifier::IGroth16VerifierBN254Dispatcher;
    use super::super::interfaces::IERC20::IERC20DispatcherTrait;
    use super::super::interfaces::IHasher::IHasherDispatcherTrait;
    use super::super::interfaces::IPool::IPoolDispatcherTrait;
    use super::super::verifier::groth16_verifier::{
        IGroth16VerifierBN254, IGroth16VerifierBN254DispatcherTrait,
    };

    const FIELD_SIZE: u256 =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    const ZERO_VALUE: u256 =
        21663839004416932945382355908790599225266501822907911457504978515578255421292; // = keccak256("tornado") % FIELD_SIZE


    const MAX_TREE_CAP: u32 = 1024;


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Upgrade: Upgrade,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgrade {
        #[key]
        new_classhash: ClassHash,
        owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        commitments: u256,
        d: Array<u256>,
        count: u256,
        timestamps: u256,
        tower: Array<Array<u256>>,
    }

    

    #[storage]
    struct Storage {
        commitments: Map<u256, bool>,
        nullifier_hashes: Map<u256, bool>,
        allowed_pools: Map<ContractAddress, bool>,
        pools: Map<ContractAddress, Map<u256, ContractAddress>>,
        owner: ContractAddress,
        hasher: ContractAddress,
        levels: u32,
        filled_subtrees: Map<u256, u256>,
        roots: Map<u256, u256>,
        current_root_index: u32,
        next_index: u32,
        verifier: ContractAddress,
        pool_salt: felt252,
        pool_class_hash: ClassHash,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        _hasher: ContractAddress,
        _verifier: ContractAddress,
        _poolClassHash: felt252,
    ) {
        self.owner.write(owner);

        self.hasher.write(_hasher);
        self.verifier.write(_verifier);

        self.pool_salt.write(0);
        self.pool_class_hash.write(_poolClassHash.try_into().unwrap())
    }

    #[abi(embed_v0)]
    impl Typhoon of ITyphoon<ContractState> {
        /// This function initiates a deposit in the specified pool
        ///
        /// # Parameters
        ///
        /// - `commitment`: The commitment to be deposited
        /// - `pool`: The pool where the deposit will be made
        /// - `reward`: A boolean indicating if the deposit is in reward mode
        ///
        /// # Panics
        ///
        /// - Panics if the length of `commitment` and `pool` arrays are not equal
        /// - Panics if the pool is not a known allowed pool
        fn deposit(
            ref self: ContractState, _commitment: u256, _pool: ContractAddress, _reward: bool,
        ) {
            assert!(self.allowed_pools.read(_pool) == true, "Is not an allowed pool");
            IPoolDispatcher { contract_address: _pool }.updateDay();

            let (ta, d, c) = IPoolDispatcher { contract_address: _pool }
                .processDeposit(get_caller_address(), _commitment);

            self
                .emit(
                    Deposit {
                        commitments: _commitment,
                        // roots: res,
                        d: d,
                        count: c,
                        timestamps: get_block_timestamp().into(),
                        tower: ta,
                    },
                );
        }

        /// This function initiates a withdraw in the specified pool
        ///
        /// # Parameters
        ///
        /// - `full_proof_with_hints`: The proof and hints for the withdrawal
        /// - `pool`: The pool from which the withdrawal will be made
        fn withdraw(
            ref self: ContractState, full_proof_with_hints: Span<felt252>, pool: ContractAddress,
        ) {
            assert!(self.allowed_pools.read(pool) == true, "Is not an allowed pool");
            // let mut proof = full_proof_with_hints;
            IPoolDispatcher { contract_address: pool }.processWithdraw(full_proof_with_hints);
        }

        /// This function returns a pool address for a given token and denomination
        ///
        /// # Parameters
        ///
        /// - `_token`: The token address
        /// - `_denomination`: The denomination of the token
        fn getPool(
            self: @ContractState, _token: ContractAddress, _denomination: u256,
        ) -> ContractAddress {
            return self.pools.entry(_token).entry(_denomination).read();
        }

        /// This function create anew pool for a given token and denomination
        ///
        /// # Parameters
        ///
        /// - `_token`: The token address
        /// - `_denomination`: The denomination of the token
        /// - `_day`: The current day that the pool is created
        ///
        /// # Panics
        ///
        /// - Panics if the caller is not the owner of the contract
        fn addPool(
            ref self: ContractState,
            _token: ContractAddress,
            _denomination: u256,
            _day: u256,
            _fee: u256,
        ) {
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            assert!(
                self
                    .pools
                    .entry(_token)
                    .entry(_denomination)
                    .read() == contract_address_const::<0>(),
                "Pool already exists",
            );

            let callData: [felt252; 6] = [
                _token.try_into().unwrap(), _denomination.try_into().unwrap(),
                _day.try_into().unwrap(), self.verifier.read().try_into().unwrap(),
                self.hasher.read().try_into().unwrap(), _fee.try_into().unwrap(),
            ];
            let (pool_address, _) = deploy_syscall(
                class_hash: self.pool_class_hash.read(),
                contract_address_salt: self.pool_salt.read(),
                calldata: callData.span(),
                deploy_from_zero: false,
            )
                .unwrap();
            self.pools.entry(_token).entry(_denomination).write(pool_address);
            self.pool_salt.write(self.pool_salt.read() + 1);
            self.allowed_pools.entry(pool_address).write(true);
        }

        /// This function returns the verifier address
        fn verifier(self: @ContractState) -> ContractAddress {
            return self.verifier.read();
        }

        /// This function returns the Hasher address
        fn hasher(self: @ContractState) -> ContractAddress {
            return self.hasher.read();
        }

        fn setPoolFee(ref self: ContractState, _pool: ContractAddress, _fee: u256) {
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            IPoolDispatcher { contract_address: _pool }.setWithdrawFee(_fee);
        }

        fn withdrawPoolProfit(
            ref self: ContractState,
            _pool: ContractAddress,
            _recipient: ContractAddress,
            _amount: u256,
        ) {
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            IPoolDispatcher { contract_address: _pool }.withdrawProfit(_recipient, _amount);
        }
        fn owner(self: @ContractState) -> ContractAddress {
            return self.owner.read();
        }

        fn setOwner(ref self: ContractState, _new_owner: ContractAddress) {
            assert!(
                _new_owner != contract_address_const::<0>(), "New owner cannot be zero address",
            );
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            self.owner.write(_new_owner);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert!(!new_class_hash.is_zero(), "Class hash cannot be zero");
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            syscalls::replace_class_syscall(new_class_hash).unwrap();
            self.emit(Upgrade { new_classhash: new_class_hash, owner: self.owner.read() });
        }
    }
}
