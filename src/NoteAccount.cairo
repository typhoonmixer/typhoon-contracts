#[starknet::contract]
pub mod NoteAccount {
    use starknet::storage::StoragePathEntry;
use starknet::storage::Map;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::storage::StoragePointerReadAccess;
use starknet::storage::StorageMapWriteAccess;
    use starknet::storage::StorageMapReadAccess;
    use typhoon::interfaces::INoteAccount::{INoteAccount, INoteAccountDispatcher};

    use core::starknet::storage::{StoragePath, Mutable};

    #[storage]
    struct Storage {
        notes: Map<u256, Map<u256, (u256, u256, u256, u256, u256, u256, u256)>>,
        notesCount: Map<u256, u256>
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    impl NoteAccount of INoteAccount<ContractState> {
        fn addNote(ref self: ContractState, pubKey: u256, encryptedNote: Span<felt252>) {

        }
        fn getNotes(self: @ContractState, pubKey: u256) -> Array<(u256, u256, u256, u256, u256, u256, u256)> {
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
        fn updateNotes(ref self: ContractState,pubKey: u256 ,newNotes: Array<(u256, u256, u256, u256, u256, u256, u256)>){
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

    fn eraseNotes(ref self: ContractState, pubKey: u256){
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
