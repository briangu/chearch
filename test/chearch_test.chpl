use Logging, SearchIndex;

config const testSerialization = true;
config const testMemorySegment = true;

proc testDocumentIdIndexSerialization() {
  coforall poolBankIndex in 0..3:uint(32) {
    forall poolBankSubIndex in 0..3:uint(32) {
      var bankEntryIndexMax = ((1: uint(32)) << documentIdPoolEntrySizes(poolBankIndex)): uint(32);
      for bankEntryIndex in 0..bankEntryIndexMax-1 {
        var bankEntryPosMax = (2 ** documentIdPoolEntrySizes(poolBankIndex)):uint(32) - 1;
        for bankEntryPos in 0..bankEntryPosMax-1 {
          var poolIndex = assembleDocumentIdPoolIndex(poolBankIndex, poolBankSubIndex, bankEntryIndex, bankEntryPos);
          var (a, b, c, d) = splitDocumentIdPoolIndex(poolIndex);
          if (a != poolBankIndex) then halt("a != ", poolBankIndex, " got ", a);
          if (b != poolBankSubIndex) then halt("b != ", poolBankSubIndex, " got ", b);
          if (c != bankEntryIndex) then halt("c != ", bankEntryIndex, " got ", c);
          if (d != bankEntryPos) then halt("d != ", bankEntryPos, " got ", d);
        }
      }
    }
  }
}

proc testDocumentIdSerialization() {
  coforall i in 0..255: TextLocation {
    for j in 0..((1 << 24): uint(32) - 1): DocumentIndex {
      var docId = assembleDocId(j, i);
      var (a, b) = splitDocId(docId);
      if (a != j: uint(32)) then halt("a != ", i: uint(32), " got ", a);
      if (b != i: uint(32)) then halt("b != ", j: uint(32), " got ", b);
    }
  }
}

proc testTermEntryPoolIndexSerialization() {
  coforall i in 0..255: uint(32) {
    for j in 0..((1 << 24): uint(32) - 1): uint(32) {
      var poolIndex = assembleTermEntryPoolIndex(i, j);
      var (bankIndex, entryPos) = splitTermEntryPoolIndex(poolIndex);
      if (bankIndex != i: uint(32)) then halt("bankIndex != ", i: uint(32), " got ", bankIndex);
      if (entryPos != j: uint(32)) then halt("entryPos != ", j: uint(32), " got ", entryPos);
    }
  }
}

class TestMemorySegment : MemorySegment {
  proc testAddDocId() {
    var docId = assembleDocId(1, 10);
    var poolIndex = allocateNewDocIdInDocumentIdPool(docId);
    var rDocId = getDocumentIdPoolEntryDocId(poolIndex);
    var (a, b) = splitDocId(rDocId);
    if (a != 1) then halt ("a != 1", a);
    if (b != 10) then halt ("b != 10 ", b);
  }
}

  // on Locales[0] {
  //   var terms: [0..0] IndexTerm;
  //   terms[0].term = 3;
  //   terms[0].textLocation = 6;
  //   addDocument(0: uint(32), terms, 10);
  // }

  // on Locales[1] {
  //   var terms: [0..0] IndexTerm;
  //   terms[0].term = 3;
  //   terms[0].textLocation = 15;
  //   addDocument(2: uint(32), terms, 20);
  // }


  // INTEGRATION TEST
  //
  // for partition in {0..7} {
  //   on Locales[partition % Locales.size] {
  //     writeln("partition ", partition);

  //     var part = partition;

  //     local {
  //       var terms: [0..100-1] IndexTerm;
  //       for i in terms.domain {
  //         terms[i].term = part: uint(32);
  //         terms[i].textLocation = i: TextLocation;
  //       }
  //       addDocument(part: uint(32), terms, part: uint);
  //     }
  //   }
  // }

proc main() {
  if (testSerialization) {
    writeln("Testing serialization");
    testDocumentIdIndexSerialization();
    testTermEntryPoolIndexSerialization();
    testDocumentIdSerialization();
  }

  if (testMemorySegment) {
    var memSegment = new TestMemorySegment();
    memSegment.testAddDocId();
    delete memSegment;
  }
}
