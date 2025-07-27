#[starknet::contract]
pub mod NoteAccount {
    use core::starknet::eth_address::EthAddress;
    use core::starknet::storage::{Mutable, StoragePath};
    use starknet::SyscallResultTrait;
    use starknet::eth_signature::verify_eth_signature;
    use starknet::secp256_trait::{Signature, recover_public_key, signature_from_vrs};
    use starknet::secp256k1::Secp256k1Point;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use typhoon::interfaces::INoteAccount::{INoteAccount, INoteAccountDispatcher};

    #[storage]
    struct Storage {
        notes: Map<EthAddress, Map<u256, Map<u256, u256>>>,
        notesCount: Map<EthAddress, u256>,
        usedMsgHash: Map<u256, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

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
            let mut i: u256 = 0;
            for d in encryptedNote {
                self.notes.entry(pubKey).entry(self.notesCount.read(pubKey)).entry(i).write(*d);
                i += 1;
            }

            self.notesCount.entry(pubKey).write(self.notesCount.read(pubKey) + 1);
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
            let mut notes: Array = ArrayTrait::<Array<u256>>::new();
            let mut i: u256 = 0;
            if (self.notesCount.read(pubKey) == 0) {
                let mut a: Array<Array<u256>> = ArrayTrait::<Array<u256>>::new();
                return a;
            }
            loop {
                let mut note: Array<u256> = ArrayTrait::<u256>::new();
                for j in 0..25_u256 {
                    let d = self.notes.entry(pubKey).entry(i).entry(j).read();
                    note.append(d);
                };
                notes.append(note);
                i += 1;
                if (self.notesCount.read(pubKey) == i) {
                    break;
                }
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
            newNotes: Span<Span<u256>>,
        ) {
            assert!(self.usedMsgHash.entry(msg_hash).read() == false, "msg hash already used");
            self.usedMsgHash.entry(msg_hash).write(true);
            verify_signature(pubKey, msg_hash, r, s, v);
            let mut i: u32 = 0;
            eraseNotes(ref self, pubKey);
            for i in 0..newNotes.len() {
                
                for j in 0..25_u32 {
                    let d = *newNotes[i][j];
                    self.notes.entry(pubKey).entry(i.into()).entry(j.into()).write(d);
                };
                
            }
            self.notesCount.entry(pubKey).write(newNotes.len().into());
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
            };
            i += 1;
            if (self.notesCount.read(pubKey) == i) {
                break;
            }
        };
    }
}
