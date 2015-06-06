use Chasm, Logging, SearchIndex;

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

proc testChasm() {
  var expectedTerm = 10: Term;

  var buffer = new InstructionBuffer(1024);

  var writer = new InstructionWriter(buffer);
  writer.write_push();
  writer.write_term(expectedTerm);

  buffer.rewind();
  var reader = new InstructionReader(buffer);
  var op: ChasmOp;
  var term: Term;
  op = reader.read(); 
  if (op != CHASM_PUSH) then halt("opcode should have been CHASM_PUSH: ", " got ", op, " ", reader);
  term = reader.readTerm();
  if (term != expectedTerm) then halt("term should have been ", expectedTerm, " got ", term, " ", reader);

  delete buffer;
}

class FixedDataOperand : Operand {
  var count: uint;
  var data: [0..count-1] OperandValue;
  var offset: uint = 0;

  proc hasValue(): bool {
    return offset <= data.domain.high;
  }

  proc getValue(): OperandValue {
    if (!hasValue()) {
      halt("iterated too far");
    }
    return data[offset];
  }

  proc advance() {
    if (!hasValue()) {
      halt("iterated too far");
    }
    offset += 1;
  }
}

proc testOperands() {
  {
    writeln("start validating FixedDataOperand");
    var fixed = new FixedDataOperand(1);
    fixed.data[0] = assembleDocId(10, 6);
    var count = 0;
    for result in fixed.evaluate() {
      if (result != fixed.data[0]) {
        halt("result not expected: ", result);
      }
      count += 1;
    }
    if (count != 1) {
      halt("count != 1 got ", count, fixed);
    }
    delete fixed;
    writeln("stop validating FixedDataOperand");
  }

  {
    writeln("start validating UnionOperand");
    var fixedA = new FixedDataOperand(1);
    fixedA.data[0] = assembleDocId(10, 6);

    var fixedB = new FixedDataOperand(1);
    fixedB.data[0] = assembleDocId(10, 15);

    var op = new UnionOperand(fixedA, fixedB);
    var count = 0;
    for result in op.evaluate() {
      if (result != fixedA.data[0] && result != fixedB.data[0]) {
        halt("result not expected: ", result);
      }
      count += 1;
    }
    if (count != 2) {
      halt("count != 2 got ", count, fixedA, fixedB);
    }
    delete op;
    writeln("stop validating UnionOperand");
  }

  {
    writeln("start validating IntersectionOperand");
    var fixedA = new FixedDataOperand(2);
    fixedA.data[0] = assembleDocId(8, 6);
    fixedA.data[1] = assembleDocId(10, 3);

    var fixedB = new FixedDataOperand(2);
    fixedB.data[0] = assembleDocId(10, 15);
    fixedB.data[1] = assembleDocId(12, 26);

    var op = new IntersectionOperand(fixedA, fixedB);
    var count = 0;
    for result in op.evaluate() {
      if (result != fixedA.data[1] && result != fixedB.data[0]) {
        halt("result not expected: ", result);
      }
      count += 1;
    }
    if (count != 2) {
      halt("count != 2 got ", count, fixedA, fixedB);
    }
    delete op;
    writeln("stop validating UnionOperand");
  }
}

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

  testChasm();
  testOperands();
}
