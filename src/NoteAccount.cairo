#[starknet::contract]
pub mod NoteAccount {
    use starknet::SyscallResultTrait;
use starknet::storage::StoragePathEntry;
use starknet::storage::Map;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use typhoon::interfaces::INoteAccount::{INoteAccount, INoteAccountDispatcher};
    use core::starknet::eth_address::EthAddress;
    use starknet::secp256k1::Secp256k1Point;
    use starknet::secp256_trait::{Signature, signature_from_vrs, recover_public_key};
    use starknet::eth_signature::{verify_eth_signature};
 

    use core::starknet::storage::{StoragePath, Mutable};

    #[storage]
    struct Storage {
        notes: Map<EthAddress, Map<u256, (u256, u256, u256, u256, u256, u256, u256)>>,
        notesCount: Map<EthAddress, u256>
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
        fn addNote(ref self: ContractState, pubKey: EthAddress, encryptedNote: Span<u256>, msg_hash: u256, r: u256, s: u256, v: u32) {
            // will panic if the signature is invalid
            verify_signature(pubKey, msg_hash, r, s, v);
            self.notesCount.entry(pubKey).write(self.notesCount.read(pubKey) + 1);
            self.notes.entry(pubKey).entry(self.notesCount.read(pubKey)).write((*encryptedNote[0], *encryptedNote[1], *encryptedNote[2], *encryptedNote[3], *encryptedNote[4], *encryptedNote[5], *encryptedNote[6]));
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
        fn getNotes(self: @ContractState, pubKey: EthAddress) -> Array<(u256, u256, u256, u256, u256, u256, u256)> {
            let mut notes: Array = ArrayTrait::<(u256, u256, u256, u256, u256, u256, u256)>::new();
            let mut i: u256 = 0;
            if(self.notesCount.read(pubKey) == 0){
                let mut a: Array = ArrayTrait::<(u256, u256, u256, u256, u256, u256, u256)>::new();
                a.append((0,0,0,0,0,0,0));
                return a;
            }
            loop{
                let note = self.notes.entry(pubKey).entry(i).read();
                notes.append(note);
                i+=1;
                if(self.notesCount.read(pubKey) == i){
                    break;
                }
                
            };
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
        fn updateNotes(ref self: ContractState,pubKey: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32  ,newNotes: Span<Span<u256>>){
            verify_signature(pubKey, msg_hash, r, s, v);
            let mut i: u32 = 0;
            eraseNotes(ref self,pubKey);
            loop{
                self.notes.entry(pubKey).entry(i.into()).write((*newNotes[i][0], *newNotes[i][1], *newNotes[i][2], *newNotes[i][3], *newNotes[i][4], *newNotes[i][5], *newNotes[i][6]));
                i+=1;
                if(newNotes.len() == i){
                    break;
                }
            }
            
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
    fn verify_signature(
        eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32,
    ) {
        let signature: Signature = signature_from_vrs(v, r, s);
        verify_eth_signature(:msg_hash, :signature, :eth_address);
    }

    /// Erases the notes associated with a specific public key.
    ///
    /// # Parameters
    ///
    /// - `self`: The contract state.
    /// - `pubKey`: The public key whose notes are to be erased.
    fn eraseNotes(ref self: ContractState, pubKey: EthAddress){
        let mut i: u256 = 0;
        loop{
            self.notes.entry(pubKey).entry(i).write((0,0,0,0,0,0,0));
            i+=1;
            if(self.notesCount.read(pubKey) == i){
                break;
            }
        };
    }
}
