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
        fn addNote(ref self: ContractState, pubKey: EthAddress, encryptedNote: Span<u256>, msg_hash: u256, r: u256, s: u256, v: u32) {
            // will panic if the signature is invalid
            verify_signature(pubKey, msg_hash, r, s, v);
            self.notesCount.entry(pubKey).write(self.notesCount.read(pubKey) + 1);
            self.notes.entry(pubKey).entry(self.notesCount.read(pubKey)).write((*encryptedNote[0], *encryptedNote[1], *encryptedNote[2], *encryptedNote[3], *encryptedNote[4], *encryptedNote[5], *encryptedNote[6]));
        }
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
        fn updateNotes(ref self: ContractState,pubKey: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32  ,newNotes: Array<(u256, u256, u256, u256, u256, u256, u256)>){
            verify_signature(pubKey, msg_hash, r, s, v);
            let mut i: u32 = 0;
            eraseNotes(ref self,pubKey);
            loop{
                self.notes.entry(pubKey).entry(i.into()).write(*newNotes.at(i));
                i+=1;
                if(newNotes.len() == i){
                    break;
                }
            }
            
        }
    }

    fn verify_signature(
        eth_address: EthAddress, msg_hash: u256, r: u256, s: u256, v: u32,
    ) {
        let signature: Signature = signature_from_vrs(v, r, s);
        verify_eth_signature(:msg_hash, :signature, :eth_address);
    }

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
