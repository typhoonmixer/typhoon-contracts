#[starknet::contract]
pub mod Pool {
    use starknet::storage::StoragePathEntry;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
    use super::super::interfaces::IERC20::IERC20DispatcherTrait;
    use typhoon::interfaces::IERC20::{IERC20Dispatcher};
    use typhoon::interfaces::IPool::{IPool};
    use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use starknet::{ContractAddress, get_block_timestamp, get_contract_address, get_caller_address, contract_address_const};
    use starknet::storage::Map;
    use typhoon::interfaces::IPool::IPoolDispatcherTrait;
    use super::super::verifier::groth16_verifier::IGroth16VerifierBN254DispatcherTrait;
    use super::super::verifier::groth16_verifier::IGroth16VerifierBN254;
    use super::super::interfaces::IHasher::IHasherDispatcherTrait;
    use typhoon::interfaces::IHasher::{IHasherDispatcher};
    use typhoon::interfaces::IPool::{IPoolDispatcher};

    use typhoon::verifier::groth16_verifier::{IGroth16VerifierBN254Dispatcher};

    const DAY: u64 = 86400;
    const BIPS: u256 = 100;
    const FIELD_SIZE: u256 =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // const ZERO_VALUE: u256 =
    //     21663839004416932945382355908790599225266501822907911457504978515578255421292; // = keccak256("tornado") % FIELD_SIZE
    
    const H: u256 = 127;
    const W: u256 = 4;
    const CAPACITY: u256 = 38597363079105396331939602657575601895140538433663384650215202958913929478144; // CAPACITY = W * (W**H - 1) / (W - 1)

    const ZERO_VALUES: [u256; 32] = [
        0x2fe54c60d3acabf3343a35b6eba15db4821b340f76e741e2249685ed4899af6c,
        0x256a6135777eee2fd26f54b8b7037a25439d5235caee224154186d2b8a52e31d,
        0x1151949895e82ab19924de92c40a3d6f7bcb60d92b00504b8199613683f0c200,
        0x20121ee811489ff8d61f09fb89e313f14959a0f28bb428a20dba6b0b068b3bdb,
        0x0a89ca6ffa14cc462cfedb842c30ed221a50a3d6bf022a6a57dc82ab24c157c9,
        0x24ca05c2b5cd42e890d6be94c68d0689f4f21c9cec9c0f13fe41d566dfb54959,
        0x1ccb97c932565a92c60156bdba2d08f3bf1377464e025cee765679e604a7315c,
        0x19156fbd7d1a8bf5cba8909367de1b624534ebab4f0f79e003bccdd1b182bdb4,
        0x261af8c1f0912e465744641409f622d466c3920ac6e5ff37e36604cb11dfff80,
        0x0058459724ff6ca5a1652fcbc3e82b93895cf08e975b19beab3f54c217d1c007,
        0x1f04ef20dee48d39984d8eabe768a70eafa6310ad20849d4573c3c40c2ad1e30,
        0x1bea3dec5dab51567ce7e200a30f7ba6d4276aeaa53e2686f962a46c66d511e5,
        0x0ee0f941e2da4b9e31c3ca97a40d8fa9ce68d97c084177071b3cb46cd3372f0f,
        0x1ca9503e8935884501bbaf20be14eb4c46b89772c97b96e3b2ebf3a36a948bbd,
        0x133a80e30697cd55d8f7d4b0965b7be24057ba5dc3da898ee2187232446cb108,
        0x13e6d8fc88839ed76e182c2a779af5b2c0da9dd18c90427a644f7e148a6253b6,
        0x1eb16b057a477f4bc8f572ea6bee39561098f78f15bfb3699dcbb7bd8db61854,
        0x0da2cb16a1ceaabf1c16b838f7a9e3f2a3a3088d9e0a6debaa748114620696ea,
        0x24a3b3d822420b14b5d8cb6c28a574f01e98ea9e940551d2ebd75cee12649f9d,
        0x198622acbd783d1b0d9064105b1fc8e4d8889de95c4c519b3f635809fe6afc05,
        0x29d7ed391256ccc3ea596c86e933b89ff339d25ea8ddced975ae2fe30b5296d4,
        0x19be59f2f0413ce78c0c3703a3a5451b1d7f39629fa33abd11548a76065b2967,
        0x1ff3f61797e538b70e619310d33f2a063e7eb59104e112e95738da1254dc3453,
        0x10c16ae9959cf8358980d9dd9616e48228737310a10e2b6b731c1a548f036c48,
        0x0ba433a63174a90ac20992e75e3095496812b652685b5e1a2eae0b1bf4e8fcd1,
        0x019ddb9df2bc98d987d0dfeca9d2b643deafab8f7036562e627c3667266a044c,
        0x2d3c88b23175c5a5565db928414c66d1912b11acf974b2e644caaac04739ce99,
        0x2eab55f6ae4e66e32c5189eed5c470840863445760f5ed7e7b69b2a62600f354,
        0x002df37a2642621802383cf952bf4dd1f32e05433beeb1fd41031fb7eace979d,
        0x104aeb41435db66c3e62feccc1d6f5d98d0a0ed75d1374db457cf462e3a1f427,
        0x1f3c6fd858e9a7d4b0d1f38e256a09d81d5a5e3c963987e2d4b814cfab7c6ebb,
        0x2c7a07d20dff79d01fecedc1134284a8d08436606c93693b67e333f671bf69cc,
    ];

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
        current_day: u256,
        token: ContractAddress,
        denomination: u256,
        fac: ContractAddress,
        withdraws_in_day: Map<u256, u256>,
        liquidity_providers: Map<u256, u256>,
        withdraw_fee: u256,
        rewarded_liquidity_providers: Map<u256, u256>,
        verifier: ContractAddress,
        commitments: Map<u256, bool>,
        nullifier_hashes: Map<u256, bool>,
        roots: Map<u256, u256>,
        current_root_index: u32,
        levels: u32,
        hasher: ContractAddress,
        filled_subtrees: Map<u256, u256>,
        next_index: u32,
        count: u256,
        D: Map<u256, u256>,
        DD: Map<u256, u256>,
        isValidDD: Map<u256, bool>,
        profit: u256,
        tower: Map<u256, Map<u256, u256>>,
        towerLv: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        _token: felt252,
        _denomination: felt252,
        _current_day: felt252,
        _verifier: felt252,
        _hasher: felt252,
        _fee: felt252,
    ) {
        self.token.write(_token.try_into().unwrap());
        self.verifier.write(_verifier.try_into().unwrap());
        self.hasher.write(_hasher.try_into().unwrap());
        self.denomination.write(_denomination.try_into().unwrap());
        self.fac.write(get_caller_address());
        self.current_day.write(_current_day.try_into().unwrap());
        self.levels.write(10);
        let onepercent: u256 = (_denomination.try_into().unwrap()) / BIPS;
        self
            .withdraw_fee
            .write(
                (onepercent * _fee.into()) / BIPS,
            ); // 0.5% withdraw fee (this can change until mainnet deployment)
        for i in 0..self.levels.read() {
            self.filled_subtrees.entry(i.into()).write(self.zeros(i))
        };
        self.roots.entry(0).write(self.zeros(self.levels.read() - 1));
    }

    #[abi(embed_v0)]
    impl Pool of IPool<ContractState> {
        /// Process the deposit of the denomination in the pool by a specific account
        /// 
        /// # Panics
        /// 
        /// This function panics if the caller is not the factory or if the commitment has already been submitted
        /// 
        /// # Parameters
        /// 
        /// - `self`: The contract state
        /// - `_from`: The address of the account making the deposit
        /// - `reward`: A boolean indicating if the deposit is eligible for a reward
        /// - `commitment`: The commitment to be processed
        /// 
        /// # Returns
        /// 
        /// A tuple containing the index of the commitment and an array of u256 values representing the subtree helper
        fn processDeposit(ref self: ContractState, _from: ContractAddress, commitment: u256) -> (Array<Array<u256>>,Array<u256>, u256) {
            assert!(get_caller_address() == self.fac.read(), "Is not the factory");
            assert!(
                self.commitments.read(commitment) == false,
                "The commitment has been submitted",
            );
            IERC20Dispatcher { contract_address: self.token.read() }
                .transferFrom(_from, get_contract_address(), self.denomination.read());
            self
                .liquidity_providers
                .entry(self.current_day.read())
                .write(self.liquidity_providers.read(self.current_day.read()) + 1);
            // if (reward) {
            //     self
            //         .rewarded_liquidity_providers
            //         .entry(self.current_day.read())
            //         .write(self.rewarded_liquidity_providers.read(self.current_day.read()) + 1)
            // }
            let roots: Array<(u256,u256,u256)> = insert(
                ref self, commitment
            );
            let mut dArr: Array<u256> = ArrayTrait::new();
            for i in 0..127_u8{
                let mut d = self.D.read(i.into());
                dArr.append(d);
            }

            let mut towerArray: Array<Array<u256>> = ArrayTrait::new();
            
            for i in 0..(self.towerLv.read() + 1) {
                let mut towerAux: Array<u256> = ArrayTrait::new();
                towerAux.append(self.tower.entry(i).entry(0).read());
                towerAux.append(self.tower.entry(i).entry(1).read());
                towerAux.append(self.tower.entry(i).entry(2).read());
                towerAux.append(self.tower.entry(i).entry(3).read());
                towerArray.append(towerAux);
            }
            
            self.commitments.write(commitment, true); 
            return (towerArray, dArr, self.count.read());    
        }

        /// Process the withdraw of the denomination from the pool by a specific account
        /// 
        /// # Panics
        /// 
        /// This function panics if the caller is not the factory or if the proof is invalid
        /// 
        /// # Parameters
        /// 
        /// - `self`: The contract state
        /// - `full_proof_with_hints`: The proof to be processed
        fn processWithdraw(ref self: ContractState, full_proof_with_hints: Span<felt252>) {
            let caller = get_caller_address();
            assert!(caller == self.fac.read(), "{:?} Is not the factory", caller);
            
            let result = IGroth16VerifierBN254Dispatcher { contract_address: self.verifier.read() }
                .verify_groth16_proof_bn254(full_proof_with_hints);
            match result {
                Option::Some(value) => {
                    assert!(
                        !self.nullifier_hashes.read(*value[0]), "The note has been already spent",
                    );
                    assert!(self.isKnownDD(*value[5]), "Invalid DD");
                    self.nullifier_hashes.write(*value[0], true);
                    let ur = *value[2];
                    let fr: felt252 = ur.try_into().unwrap();
                    let recipient: ContractAddress = fr.try_into().unwrap();
                    let ra = *value[3];
                    let fr: felt252 = ra.try_into().unwrap();
                    let relayer: ContractAddress = fr.try_into().unwrap();

                    self.emit(Withdraw { recipient: recipient, nullifierHash: *value[0] });
                    self.updateDay();
                    // let mut days = 0;
                    // let mut reward = 0;
                    // if (day != 1) {
                    //     days = getDaysPassed(value[2]);
                    //     if (days > 1) {
                    //         reward = self.calculateReward(*value[2], days);
                    //     }
                    // }

                    self
                        .withdraws_in_day
                        .write(
                            self.current_day.read(),
                            self.withdraws_in_day.read(self.current_day.read()) + 1,
                        );
                    let relayer_fee = if relayer != contract_address_const::<0>() {
                        *value[4]
                    } else {
                        0
                    };
                    IERC20Dispatcher { contract_address: self.token.read() }
                        .transfer(
                            recipient,
                            ((self.denomination.read() - self.withdraw_fee.read()) - relayer_fee),
                                // + reward,
                        );
                    self.profit.write(self.profit.read() + self.withdraw_fee.read());
                    if (*value[4] > 0 && relayer != contract_address_const::<0>()) {
                        IERC20Dispatcher { contract_address: self.token.read() }
                            .transfer(relayer, *value[4]);
                    }
                },
                Option::None => { panic!("Invalid withdraw proof"); },
            }
        }

        fn setWithdrawFee(ref self: ContractState, _fee: u256){
            assert!(get_caller_address() == self.fac.read(), "Only factory");
            assert!(_fee <= 500, "Fee should be less or equal than 5%");
            assert!(_fee > 0, "Fee should be greater than 0");
            let onepercent: u256 = (self.denomination.read()) / BIPS;
            self.withdraw_fee.write((_fee * onepercent) / BIPS);
        }

        fn withdrawProfit(ref self: ContractState, _recipient: ContractAddress, _amount: u256){
            assert!(get_caller_address() == self.fac.read(), "Only factory");
            assert!(self.profit.read() >= _amount, "Not enough profit");
            self.profit.write(self.profit.read() - _amount);
            IERC20Dispatcher { contract_address: self.token.read() }
                .transfer(_recipient, _amount);
        }

        fn getProfit(self: @ContractState) -> u256 {
            return self.profit.read();
        }


        /// This function updates the current day of the contract state
        fn updateDay(ref self: ContractState) {
            let mut cur_day = self.current_day.read();
            let mut dif: u256 = 0;
            if cur_day < get_block_timestamp().into() {
                dif = get_block_timestamp().into() - cur_day;
                if dif > DAY.into() {
                    let days = getDaysPassed(@cur_day);
                    self.current_day.write(cur_day + (DAY.into() * days));
                }
            }
        }

        /// This function returns the current day of the contract state
        fn currentDay(self: @ContractState) -> u256 {
            return self.current_day.read();
        }

        fn getCount(self: @ContractState) -> u256 {
            return self.count.read();
        }

        fn getLeafAt(self: @ContractState, lv: u256, ll: u256) -> u256 {
            return self.tower.entry(lv).entry(ll).read();
        }

        /// This function calculates the reward for the liquidity providers
        /// 
        /// # Parameters
        /// 
        /// - `self`: The contract state
        /// - `start_day`: The start day of the reward calculation
        /// - `days`: The number of days to calculate the reward for
        /// 
        /// # Returns
        /// 
        /// The calculated reward for the liquidity providers
        fn calculateReward(self: @ContractState, start_day: u256, days: u256) -> u256 {
            let mut accrued_fee: u256 = 0;
            let mut total_lps: u256 = 0;
            // needs to hold for at least 1 day
            let s_day = start_day + DAY.into();
            for i in 0..days {
                total_lps = total_lps
                    + self.rewarded_liquidity_providers.read(s_day + (DAY.into() * i));
                let wd = self.withdraws_in_day.read(s_day + (DAY.into() * i));
                accrued_fee = accrued_fee + (wd * self.withdraw_fee.read());
            };
            let lps_part = (accrued_fee * 80) / 100; // 80% of the fees goes to the LPs
            let lp_share = lps_part / total_lps;
            return lp_share;
        }

        /// This function returns the factory address of the contract state
        fn factory(self: @ContractState) -> ContractAddress {
            return self.fac.read();
        }

        /// This function returns the number of liquidity providers in a specific day
        fn liquidityProviders(self: @ContractState, _day: u256) -> u256 {
            return self.liquidity_providers.read(_day);
        }

        /// This function returns the number of rewarded liquidity providers in a specific day
        fn rewardedLiquidityProviders(self: @ContractState, _day: u256) -> u256 {
            return self.rewarded_liquidity_providers.read(_day);
        }

        /// This function returns the number of withdraws in a specific day
        fn withdrawsInDay(self: @ContractState, _day: u256) -> u256 {
            return self.withdraws_in_day.read(_day);
        }

        /// This function returns the token address of the pool
        fn token(self: @ContractState) -> ContractAddress {
            return self.token.read();
        }

        /// This function returns the denomination of the pool
        fn denomination(self: @ContractState) -> u256 {
            return self.denomination.read();
        }

        /// This function returns the withdraw fee of the pool
        fn withdrawFee(self: @ContractState) -> u256 {
            return self.withdraw_fee.read();
        }

        /// This function check if is a known root
        /// 
        /// # Parameters
        /// 
        /// - `self`: The contract state
        /// - `_root`: The root to check
        /// 
        /// # Returns
        /// 
        /// A boolean indicating if the root is known
        fn isKnownDD(self: @ContractState, _dd: u256) -> bool {
            return self.isValidDD.read(_dd);
        }

        /// This function returns the zero value for a specific index
        fn zeros(self: @ContractState, i: u32) -> u256 {
            let zeroArraySpan = ZERO_VALUES.span();
            return *zeroArraySpan[i];
        }

        /// This function hashes two values using the MiMC5 hash function
        /// 
        /// # Parameters
        /// 
        /// - `self`: The contract state
        /// - `_left`: The left value to hash
        /// - `_right`: The right value to hash
        ///
        /// # Panics
        /// 
        /// This function panics if the left or right value is outside the field size
        /// 
        /// # Returns
        /// 
        /// The hash of the two values
        fn hashLeftRight(self: @ContractState, _left: u256, _right: u256) -> u256 {
            assert!(_left < FIELD_SIZE, "_left should be inside the field");
            assert!(_right < FIELD_SIZE, "_right should be inside the field");
            let result = IHasherDispatcher { contract_address: self.hasher.read() }
                .MiMC5Sponge([_left, _right], 0);
            return result;
        }

        /// This function returns the last root of the pool
        fn getLastRoot(self: @ContractState) -> u256 {
            return self.roots.entry(self.current_root_index.read().into()).read();
        }

        /// This function checks if a nullifier hash has been spent
        fn isSpent(self: @ContractState, _nullifierHash: u256) -> bool {
            return self.nullifier_hashes.read(_nullifierHash);
        }
    }

    /// This function returns the number of days passed since the current day
    /// 
    /// # Parameters
    /// 
    /// - `current_day`: The current day to check
    /// 
    /// # Returns
    /// 
    /// The number of days passed since the current day
    fn getDaysPassed(current_day: @u256) -> u256 {
        if (*current_day > get_block_timestamp().into()) {
            return 0;
        }
        let dif = get_block_timestamp().into() - *current_day;
        let r = dif % DAY.into();
        let days = (dif - r) / DAY.into();
        return days;
    }

    fn insert(ref self: ContractState, _leaf: u256) -> Array<(u256, u256, u256)> {
        let mut roots: Array<(u256, u256, u256)> = ArrayTrait::new();
        let _nextIndex: u32 = self.next_index.read();
        
        let mut currentDay = 1;
        let mut leafHash = IHasherDispatcher { contract_address: self.hasher.read() }
            .MiMC5Sponge([_leaf, currentDay], 0);
        let mut _count = self.count.read();
        assert!(_count < CAPACITY, "Pool is full");
        let mut z: u256 = 0;
        let mut fl: u256 = 0;
        let mut ll: u256 = 0;
        let mut lv: u256 = 0;
        let mut W_pow_lv: u256 = 1; // W ** lv

        loop{
          z += W_pow_lv;
          if(_count < z){
            fl = 0;
          } else {
            fl = (_count - z) / W_pow_lv + 1;
          }
          if (fl == 0) {
            ll = 0;
          } else {
            ll = (fl - 1) % W + 1;
          }
          if ll < W {
            break;
          }
          lv+=1;
          W_pow_lv *= W;
        };

        let mut v: u256 = 0;
        if(lv > 0){
            v = self.D.entry(lv - 1).read();
        } else {
            v = leafHash;
        }
        roots.append((lv, fl, v));
        insertToTower(ref self, v, ll, lv);

        let mut d: u256 = 0;
        if ll == 0 {
            d = v
        } else {
            d = IHasherDispatcher { contract_address: self.hasher.read() }
            .MiMC5Sponge([self.D.entry(lv).read(), v], 0);
        }
        let mut dd: u256 = 0;
        if fl == ll {
            dd = d;
        } else {
            dd = IHasherDispatcher { contract_address: self.hasher.read() }
            .MiMC5Sponge([self.DD.entry(lv+1).read(), d], 0);
        }

        let mut prevDd = 0;
        loop{
            self.isValidDD.entry(dd).write(true);
            self.D.entry(lv).write(d);
            self.DD.entry(lv).write(dd);
            if lv == 0 {
                break;
            }
            z -= W_pow_lv;
            prevDd = dd;
            lv-=1;
            W_pow_lv /= W;
            fl = (_count - z) / W_pow_lv + 1;
            if lv > 0{
                v = self.D.entry(lv - 1).read();
            } else {
                v = leafHash;
            }
            roots.append((lv, fl, v));
            insertToTower(ref self, v, 0, lv);
            d = v;
            dd = IHasherDispatcher { contract_address: self.hasher.read() }
            .MiMC5Sponge([prevDd, d], 0);            

        }
        self.count.write(_count + 1);
        
        return roots;
    }

    fn insertToTower(ref self: ContractState, _leaf: u256, ll: u256, lv: u256) {
        self.tower.entry(lv).entry(ll).write(_leaf);
        if(ll == 0){
            self.tower.entry(lv).entry(1).write(0);
            self.tower.entry(lv).entry(2).write(0);
            self.tower.entry(lv).entry(3).write(0);
        }
        if(lv > self.towerLv.read()) {
            self.towerLv.write(lv);
        }
    }
    /// This function inserts a new leaf into the Merkle tree
    /// 
    /// # Parameters
    /// 
    /// - `self`: The contract state
    /// - `_leaf`: The leaf to insert
    /// - `_reward`: A boolean indicating if the leaf is eligible for a reward
    /// 
    /// # Returns
    /// 
    /// A tuple containing the index of the leaf and an array of u256 values representing the subtree helper
    // fn insert(
    //     ref self: ContractState, _leaf: u256,
    // ) -> (u256, Array<u256>) {
    //     let _nextIndex: u32 = self.next_index.read();
    //     let mut currentIndex: u32 = _nextIndex;
    //     let mut currentDay = 1;
    //     // if (_reward == true) {
    //     //     currentDay = self.currentDay();
    //     // }
    //     let mut currentLevelHash = IHasherDispatcher { contract_address: self.hasher.read() }
    //         .MiMC5Sponge([_leaf, currentDay], 0);
    //     let mut left: u256 = 0;
    //     let mut right: u256 = 0;
    //     let mut subtree_helper: Array<u256> = ArrayTrait::new();

    //     for i in 0..self.levels.read() {
    //         if currentIndex % 2 == 0 {
    //             left = currentLevelHash;
    //             right = self.zeros(i);
    //             self.filled_subtrees.entry(i.into()).write(currentLevelHash)
    //         } else {
    //             left = self.filled_subtrees.entry(i.into()).read();
    //             right = currentLevelHash;
    //             subtree_helper.append(self.filled_subtrees.entry(i.into()).read())
    //         }

    //         currentLevelHash = self.hashLeftRight(left, right);
    //         currentIndex = currentIndex / 2;
    //     };
    //     let newRootIndex: u32 = (self.current_root_index.read() + 1);
    //     self.current_root_index.write(newRootIndex);
    //     self.roots.entry(newRootIndex.into()).write(currentLevelHash);
    //     self.next_index.write(_nextIndex + 1);
    //     return (_nextIndex.into(), subtree_helper);
    // }
}
