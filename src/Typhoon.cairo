#[starknet::contract]
pub mod Typhon {
    use super::super::verifier::groth16_verifier::IGroth16VerifierBN254DispatcherTrait;
    use super::super::verifier::groth16_verifier::IGroth16VerifierBN254;
    use starknet::event::EventEmitter;
    use core::pedersen::PedersenTrait;
    use super::super::interfaces::IHasher::IHasherDispatcherTrait;
    use core::circuit::CircuitInputs;
    use starknet::storage::StoragePathEntry;
    use super::super::interfaces::IPool::IPoolDispatcherTrait;
    use super::super::interfaces::IERC20::IERC20DispatcherTrait;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{
        ContractAddress, get_block_timestamp, get_contract_address, get_caller_address,
        contract_address_const,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::class_hash::ClassHash;


    use typhoon::interfaces::ITyphoon::{ITyphoon};
    use typhoon::interfaces::IPool::{IPoolDispatcher};
    use typhoon::interfaces::IHasher::{IHasherDispatcher};
    use starknet::storage::Map;
    use typhoon::verifier::groth16_verifier::{IGroth16VerifierBN254Dispatcher};

    const FIELD_SIZE: u256 =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    const ZERO_VALUE: u256 =
        21663839004416932945382355908790599225266501822907911457504978515578255421292; // = keccak256("tornado") % FIELD_SIZE


    const MAX_TREE_CAP: u32 = 1024;


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposit {
        #[key]
        commitments: Array<u256>,
        insertedIndexs: Array<u256>,
        subtreeHelper: Array<Array<u256>>,
        timestamps: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        recipient: ContractAddress,
        nullifierHash: u256,
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
        fn deposit(
            ref self: ContractState,
            _commitment: Array<u256>,
            _pool: Array<ContractAddress>,
            _reward: bool,
        ) {
            assert!(
                _commitment.len() == _pool.len(),
                "commitments and pools needs to have the same length",
            );

            let mut insertedIndexs: Array<u256> = ArrayTrait::new();
            let mut subtreeHelper: Array<Array<u256>> = ArrayTrait::new();

            for i in 0.._commitment.len() {
                
                assert!(self.allowed_pools.read(*_pool.at(i)) == true, "Is not an allowed pool");
                IPoolDispatcher { contract_address: *_pool.at(i) }.updateDay();

                let (index, subtree) = IPoolDispatcher { contract_address: *_pool.at(i) }
                    .processDeposit(get_caller_address(), _reward, *_commitment.at(i));
                insertedIndexs.append(index);
                subtreeHelper.append(subtree);
            };

            self
                .emit(
                    Deposit {
                        commitments: _commitment,
                        insertedIndexs: insertedIndexs,
                        subtreeHelper: subtreeHelper,
                        timestamps: get_block_timestamp().into(),
                    },
                );
        }

        // URGENT: TEST IF IS POSSIBLE TO WITHDRAW FROM A POOL THAT THE USER DOES NOT MAKE DEPOSIT
        // IF SO, THEN MOVE THE MERKLE TREE TO THE POOL CONTRACT
        fn withdraw(
            ref self: ContractState, full_proof_with_hints: Span<felt252>, pool: ContractAddress,
        ) {
            IPoolDispatcher { contract_address: pool }.processWithdraw(full_proof_with_hints);
        }

        fn getPool(
            self: @ContractState, _token: ContractAddress, _denomination: u256,
        ) -> ContractAddress {
            return self.pools.entry(_token).entry(_denomination).read();
        }
        fn addPool(
            ref self: ContractState, _token: ContractAddress, _denomination: u256, _day: u256,
        ) {
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            let callData: [felt252; 5] = [
                _token.try_into().unwrap(), _denomination.try_into().unwrap(),
                _day.try_into().unwrap(),
                self.verifier.read().try_into().unwrap(),
                self.hasher.read().try_into().unwrap(),
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

        fn verifier(self: @ContractState) -> ContractAddress {
            return self.verifier.read();
        }

        fn hasher(self: @ContractState) -> ContractAddress {
            return self.hasher.read();
        }
    }
}
