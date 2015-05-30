/**
  [] [subPool0] [entries]
     [subPool1]
     [subPool2]
     [subPool3]
  [] []
     []
     []
     []
  [] []
     []
     []
     []
  [] []
     []
     []
     []
*/

module DocumentIdPool {

  use DocumentId;

  type DocIdPoolIndex = uint(32);

  inline proc documentIdPoolEntrySizes(poolBankIndex: uint(32)): int {
    select poolBankIndex {
      when 0 do return 1;
      when 1 do return 4;
      when 2 do return 7;
      when 3 do return 11;
    }
    halt("documentIdPoolEntrySizes: unhandled poolBankIndex");
    return 0;
  }

  inline proc bankEntryPositionFromDocumentIdPoolIndex(poolIndex: DocIdPoolIndex): uint(32) {
    var poolBankIndex = poolBankIndexFromDocumentIdPoolIndex(poolIndex);
    select poolBankIndex {
      when 0 do return poolIndex & ((1: DocIdPoolIndex) << 1 - 1);
      when 1 do return poolIndex & ((1: DocIdPoolIndex) << 4 - 1);
      when 2 do return poolIndex & ((1: DocIdPoolIndex) << 7 - 1);
      when 3 do return poolIndex & ((1: DocIdPoolIndex) << 11 - 1);
    }
    halt("bankEntryPositionFromDocumentIdPoolIndex: unhandled poolBankIndex");
    return 0;
  }

  // bank entry bit-partition depends upon which pool bank
  inline proc bankEntryIndexFromDocumentIdPoolIndex(poolIndex: DocIdPoolIndex): uint(32) {
    var poolBankIndex = poolBankIndexFromDocumentIdPoolIndex(poolIndex);
    return (poolIndex & 0x0FFFFFFF) >> documentIdPoolEntrySizes(poolBankIndex);
  }

  // pool bank sub-index bits 29-28
  inline proc poolBankSubIndexFromDocumentIdPoolIndex(poolIndex: DocIdPoolIndex): uint(32) {
    return (poolIndex >> 28) & 0x03;
  }

  // pool bank index is bits 31-30
  inline proc poolBankIndexFromDocumentIdPoolIndex(poolIndex: DocIdPoolIndex): uint(32) {
    return (poolIndex >> 30);
  }

  inline proc assembleDocumentIdPoolIndex(poolBankIndex: uint(32), poolBankSubIndex: uint(32), entryIndex: uint(32), entryPos: uint(32)): DocIdPoolIndex {
    return (
      (poolBankIndex: DocIdPoolIndex << 30) | 
      (poolBankSubIndex: DocIdPoolIndex << 28) | 
      (entryIndex: DocIdPoolIndex << documentIdPoolEntrySizes(poolBankIndex)) |
      (entryPos: DocIdPoolIndex));
  }

  inline proc splitDocumentIdPoolIndex(poolIndex: DocIdPoolIndex): (uint(32), uint(32), uint(32), uint(32)) {
    return (
      poolBankIndexFromDocumentIdPoolIndex(poolIndex), 
      poolBankSubIndexFromDocumentIdPoolIndex(poolIndex),
      bankEntryIndexFromDocumentIdPoolIndex(poolIndex), 
      bankEntryPositionFromDocumentIdPoolIndex(poolIndex)
    );
  }

  class DocumentIdPoolBankEntry {
    var bankSize: int;
    var previousPoolIndex: DocIdPoolIndex;
    var documentIds: [0..bankSize-1] DocId;
  }

  class DocumentIdPoolBankSubPool {
    var bankSize: int;
    var subPoolEntryCount: uint(32);
    var entries: [0..subPoolEntryCount-1] DocumentIdPoolBankEntry;
  }

  class DocumentIdPoolBank {
    var bankSize: int;
    var subPoolEntryCount: uint(32);
    var subPool: [0..3] DocumentIdPoolBankSubPool;
    var subPoolIndex = -1;
    var entryCount = -1;
  }
}
