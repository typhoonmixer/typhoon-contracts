#[starknet::contract]
pub mod NoteAccount {
    use core::num::traits::Zero;
    use core::starknet::eth_address::EthAddress;
    use core::starknet::storage::{Mutable, StoragePath};
    use starknet::eth_signature::verify_eth_signature;
    use starknet::secp256_trait::{Signature, recover_public_key, signature_from_vrs};
    use starknet::secp256k1::Secp256k1Point;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ClassHash, ContractAddress, SyscallResultTrait, contract_address_const, get_caller_address,
        get_contract_address, syscalls,
    };
    use typhoon::interfaces::INoteAccount::{INoteAccount, INoteAccountDispatcher};

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Upgrade: Upgrade,
    }

    #[derive(Drop, starknet::Event)]
    struct Upgrade {
        #[key]
        new_classhash: ClassHash,
        owner: ContractAddress,
    }

    struct Node {
        value: felt252,
        next: u256,
        prev: u256,
    }

    #[storage]
    struct Storage {
        notes: Map<EthAddress, Map<u256, Map<u256, u256>>>,
        notesCount: Map<EthAddress, u256>,
        usedMsgHash: Map<u256, bool>,
        owner: ContractAddress,
        // telegram username hash to Eth address
        userIdToAddress: Map<u256, EthAddress>,
        // Eth address to telegram username hash
        addressToUserId: Map<EthAddress, u256>,
        // eth address will store the pub key X and Y
        addressToPubKey: Map<EthAddress, Map<u256, u256>>,
        values: Map<EthAddress, Map<u256, Map<u256, u256>>>,
        // Linked list pointers
        next: Map<EthAddress, Map<u256, u256>>,
        prev: Map<EthAddress, Map<u256, u256>>,
        // Pointers to the list ends
        head: Map<EthAddress, u256>,
        tail: Map<EthAddress, u256>,
        // Incremental ID for new elements
        next_id: Map<EthAddress, u256>,
        // Number of elements
        length: Map<EthAddress, u256>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
    }

    #[abi(embed_v0)]
    impl NoteAccount of INoteAccount<ContractState> {
        /// Adds a note to a specific public key.
        ///
        /// # Parameters
        ///
        /// - `self`: The contract state.
        /// - `pubKey`: The public key associated with the note.
        /// - `encryptedNote`: The encrypted note to be added.
        /// - `msg_hash`: The hash of the message to be verified.
        /// - `r`: The r component of the signature.
        /// - `s`: The s component of the signature.
        /// - `v`: The v component of the signature.
        ///
        /// # Panics
        ///
        /// - Panics if the signature is invalid.
        fn addNote(
            ref self: ContractState,
            pubKey: EthAddress,
            encryptedNote: Span<u256>,
            msg_hash: u256,
            r: u256,
            s: u256,
            v: u32,
        ) {
            // will panic if the signature is invalid
            assert!(self.usedMsgHash.entry(msg_hash).read() == false, "msg hash already used");
            self.usedMsgHash.entry(msg_hash).write(true);
            verify_signature(pubKey, msg_hash, r, s, v);
            push_back(ref self, pubKey, encryptedNote);
        }

        /// Retrieves the notes associated with a specific public key.
        ///
        /// # Parameters
        ///
        /// - `self`: The contract state.
        /// - `pubKey`: The public key whose notes are to be retrieved.
        ///
        /// # Returns
        ///
        /// - An array of tuples containing the notes data.
        fn getNotes(self: @ContractState, pubKey: EthAddress) -> Array<Array<u256>> {
            let mut notes: Array<Array<u256>> = ArrayTrait::new();
            let len = self.length.entry(pubKey).read();
            // for i in 0..len{
            //     let mut notesAux: Array<u256> = ArrayTrait::new();
            //     for j in 0..25_u256{
            //         notesAux.append(self.values.entry(pubKey).entry(i).entry(j).read());
            //     };
            //     notes.append(notesAux);
            // };
            let mut current = self.head.entry(pubKey).read();
            let mut i = self.length.entry(pubKey).read();
            loop {
                if (i == 0) {
                    break;
                }
                let mut notesAux: Array<u256> = ArrayTrait::new();
                for j in 0..25_u256 {
                    notesAux.append(self.values.entry(pubKey).entry(current).entry(j).read());
                }
                notes.append(notesAux);
                current = self.next.entry(pubKey).entry(current).read();
                i -= 1;
            }
            return notes;
        }

        /// Updates the notes associated with a specific public key.
        ///
        /// # Parameters
        ///
        /// - `self`: The contract state.
        /// - `pubKey`: The public key whose notes are to be updated.
        /// - `msg_hash`: The hash of the message to be verified.
        /// - `r`: The r component of the signature.
        /// - `s`: The s component of the signature.
        /// - `v`: The v component of the signature.
        /// - `newNotes`: An array of tuples containing the new notes data.
        ///
        /// # Panics
        ///
        /// - Panics if the signature is invalid.
        fn updateNotes(
            ref self: ContractState,
            pubKey: EthAddress,
            msg_hash: u256,
            r: u256,
            s: u256,
            v: u32,
            noteIndex: u256,
        ) {
            assert!(self.usedMsgHash.entry(msg_hash).read() == false, "msg hash already used");
            assert!(noteIndex < self.length.entry(pubKey).read(), "invalid note index");
            self.usedMsgHash.entry(msg_hash).write(true);
            verify_signature(pubKey, msg_hash, r, s, v);
            let mut id = self.head.entry(pubKey).read();
            let mut i = noteIndex;
            loop {
                if (i == 0) {
                    break;
                }
                
                id = self.next.entry(pubKey).entry(id).read();
                i -= 1;
            };
            remove(ref self, id, pubKey);
        }

        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert!(!new_class_hash.is_zero(), "Class hash cannot be zero");
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            syscalls::replace_class_syscall(new_class_hash).unwrap();
            self.emit(Upgrade { new_classhash: new_class_hash, owner: self.owner.read() });
        }

        fn setOwner(ref self: ContractState, new_owner: ContractAddress) {
            assert!(new_owner != contract_address_const::<0>(), "New owner cannot be zero address");
            assert!(get_caller_address() == self.owner.read(), "Only owner");
            self.owner.write(new_owner);
        }
        fn getOwner(self: @ContractState) -> ContractAddress {
            return self.owner.read();
        }
    }

    /// Verifies the signature of a message.
    ///
    /// # Parameters
    ///
    /// - `eth_address`: The Ethereum address associated with the signature.
    /// - `msg_hash`: The hash of the message to be verified.
    /// - `r`: The r component of the signature.
    /// - `s`: The s component of the signature.
    /// - `v`: The v component of the signature.
    ///
    /// # Panics
    ///
    /// - Panics if the signature is invalid.
    fn verify_signature(eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32) {
        let signature: Signature = signature_from_vrs(v, r, s);
        verify_eth_signature(msg_hash, signature, eth_address);
    }

    fn push_back(ref self: ContractState, pubKey: EthAddress, encryptedNote: Span<u256>) {
        let id = self.next_id.entry(pubKey).read();
        self.next_id.entry(pubKey).write(id + 1);

        let mut i: u256 = 0;
        for d in encryptedNote {
            self.values.entry(pubKey).entry(id).entry(i).write(*d);
            i += 1;
        }

        let len = self.length.entry(pubKey).read();
        if len == 0 {
            self.head.entry(pubKey).write(id);
            self.tail.entry(pubKey).write(id);
        } else {
            let last = self.tail.entry(pubKey).read();
            self.next.entry(pubKey).entry(last).write(id);
            self.prev.entry(pubKey).entry(id).write(last);
            self.tail.entry(pubKey).write(id);
        }

        self.length.entry(pubKey).write(len + 1);
    }

    fn remove(ref self: ContractState, id: u256, pubKey: EthAddress) {
        let prev = self.prev.entry(pubKey).read(id);
        let next = self.next.entry(pubKey).read(id);

        if self.values.entry(pubKey).entry(prev).entry(0).read() != 0 {
            self.next.entry(pubKey).entry(prev).write(next);
        } else {
            self.head.entry(pubKey).write(next);
        }

        if self.values.entry(pubKey).entry(next).entry(0).read() != 0 {
            self.prev.entry(pubKey).entry(next).write(prev);
        } else {
            self.tail.entry(pubKey).write(prev);
        }

        for i in 0..25_u256 {
            self.values.entry(pubKey).entry(id).entry(i).write(0);
        }
        self.prev.entry(pubKey).entry(id).write(0);
        self.next.entry(pubKey).entry(id).write(0);

        self.length.entry(pubKey).write(self.length.entry(pubKey).read() - 1);
    }


    /// Erases the notes associated with a specific public key.
    ///
    /// # Parameters
    ///
    /// - `self`: The contract state.
    /// - `pubKey`: The public key whose notes are to be erased.
    fn eraseNotes(ref self: ContractState, pubKey: EthAddress) {
        let mut i: u256 = 0;
        let e: Array<u256> = ArrayTrait::<u256>::new();
        loop {
            for j in 0..25_u256 {
                self.notes.entry(pubKey).entry(i).entry(j).write(0);
            }
            i += 1;
            if (self.notesCount.read(pubKey) == i) {
                break;
            }
        };
    }
}
