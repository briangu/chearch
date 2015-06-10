module MemorySegment {

  use Chasm, DocumentId, DocumentIdPool, GenHashKey32, Logging, Search, Time;

  config const termHashTableSize: uint = 1024 * 32;

  type TermEntryPoolIndex = uint(32);

  const termEntryPoolBankEntryCount: uint = 2 ** 24; // 256 banks of 2**24 entries => 24 + 8

  inline proc assembleTermEntryPoolIndex(bankIndex: uint(32), entryPos: uint(32)): TermEntryPoolIndex {
    return ((bankIndex: TermEntryPoolIndex) << 24) | (0x00FFFFFF & (entryPos: TermEntryPoolIndex));
  }

  inline proc splitTermEntryPoolIndex(poolIndex: TermEntryPoolIndex): (uint(32), uint(32)) {
    var bankIdx = ((poolIndex & 0xFF000000) & poolIndex) >> 24;
    var entryPos = (poolIndex & 0x00FFFFFF);
    return (bankIdx, entryPos);
  }

  class TermEntryOperand: Operand {
    var segment: MemorySegment;
    var term: TermEntry;
    var lastDocIdIndex = term.lastDocIdIndex.read();
    var entry = segment.getDocumentIdPoolEntry(lastDocIdIndex);
    var entryPos = bankEntryPositionFromDocumentIdPoolIndex(lastDocIdIndex);

    inline proc hasValue(): bool {
      return entry != nil;
    }

    inline proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("iterated past end of document ids", term);
      }

      var docId = entry.documentIds[entryPos];
      return ((term.term: OperandValue) << 32) | (docId: OperandValue);
    }

    inline proc advance() {
      if (!hasValue()) {
        halt("iterated past end of document ids", term);
      }

      entryPos -= 1;
      if (entryPos >= entry.bankSize) { // uint's will roll over
        if (entry.bankSize > 2) {
          entry = segment.getDocumentIdPoolEntry(entry.previousPoolIndex);
          entryPos = (entry.bankSize - 1): uint(32);
        } else {
          entry = nil;
        }
      }
    }
  }

  class TermEntry {
    var term: Term;

    // pointer to the last document id in the doc id pool
    var lastDocIdIndex: atomic DocIdPoolIndex;

    // next term in the bucket chain
    var next: atomic TermEntryPoolIndex;

    proc TermEntry(term: Term, poolIndex: TermEntryPoolIndex) {
      this.term = term;
      this.next.write(poolIndex);
    }

    // total number of documents this term appears in
    var documentIdCount: atomic uint;
  }

  class MemorySegment : Segment {

    proc MemorySegment() {
      // ADD DUMMY to fill term 0
      var dummy: [0..0] IndexTerm;
      dummy[0].term = ~(0:uint(32));
      dummy[0].textLocation = 0;
      addDocument(dummy, ~(0:uint));
    }

    class TermEntryPoolBank {
      var entries: [0..termEntryPoolBankEntryCount-1] TermEntry;
    }

    // use an array of TermEntryPoolBank so that we don't have to allocate all term entry slots up front
    var termEntryPool: [0..255] TermEntryPoolBank;
    var termEntryPoolBankIndex = -1; // current pool bank, which is a function of total term entry count
    var termEntryPoolEntryCount = -1; // total number of entries in the pool

    proc setTermEntryAtNextTermEntryPoolIndex(entry: TermEntry) {
      termEntryPoolEntryCount += 1;

      var termEntryPoolEntryPos = termEntryPoolEntryCount: uint % termEntryPoolBankEntryCount;
      if (termEntryPoolEntryPos == 0) {
        termEntryPoolBankIndex += 1; 
        termEntryPool[termEntryPoolBankIndex] = new TermEntryPoolBank();
      }

      termEntryPool[termEntryPoolBankIndex].entries[termEntryPoolEntryPos] = entry;

      return assembleTermEntryPoolIndex(termEntryPoolBankIndex: uint(32), termEntryPoolEntryPos: uint(32));
    }

    proc getTermEntryPoolEntry(poolIndex: TermEntryPoolIndex) {
      var (bankIndex, entryPos) = splitTermEntryPoolIndex(poolIndex);
      return termEntryPool[bankIndex].entries[entryPos];
    }

    // document index table: map to external document id
    var externalDocumentIds: [0..MaxDocumentIndexCount-1] ExternalDocId;

    // total documents stored in the segment (must be less-than MaxDocumentIndexCount)
    var documentCount: atomic uint(32);

    // Master table from term -> TermEntry -> Document posting list
    // This is a lock-free table and uses atomic TermEntryPoolIndex values to point to allocatiosn in the TermEntryPool
    var termHashTable: [0..termHashTableSize-1] atomic TermEntryPoolIndex;

    inline proc tableIndexForTerm(term: Term): uint {
      return genHashKey32(term) % termHashTable.size: uint(32);
    }

    inline proc isSegmentFull(): bool {
      return documentIndexFromDocId(documentCount.read()) >= MaxDocumentIndexCount;
    }

    inline proc externalDocumentIdFromDocId(docId: DocId): ExternalDocId {
      return externalDocumentIds[documentIndexFromDocId(docId)];
    }

    inline proc externalDocumentIdFromDocumentIndex(documentIndex: DocumentIndex): ExternalDocId {
      return externalDocumentIds[documentIndex];
    }

    // ************************
    // BUG: by having an array of objects it causes Chapel to use N-1 CPUs at 100%
    // ************************
    // // use an array of DocumentIdPoolBankSubPool so that we don't have to allocate everything up front
    // var documentIdPool: [0..3] DocumentIdPoolBank = [
    //   new DocumentIdPoolBank(1 << 1, 1 << 23), // 2 + 2 + 1 + 27 = 32 = 2 + 2 + 1 + 23 + 4
    //   new DocumentIdPoolBank(1 << 4, 1 << 20), // 2 + 2 + 4 + 24 = 32 = 2 + 2 + 4 + 20 + 4
    //   new DocumentIdPoolBank(1 << 7, 1 << 17), // 2 + 2 + 7 + 21 = 32 = 2 + 2 + 4 + 17 + 4
    //   new DocumentIdPoolBank(1 << 11, 1 << 13) // 2 + 2 + 11 + 17 = 32 = 2 + 2 + 4 + 13 + 4
    // ];

    var documentIdPool0 = new DocumentIdPoolBank(1 << 1, 1 << 23);
    var documentIdPool1 = new DocumentIdPoolBank(1 << 4, 1 << 20);
    var documentIdPool2 = new DocumentIdPoolBank(1 << 7, 1 << 17);
    var documentIdPool3 = new DocumentIdPoolBank(1 << 11, 1 << 13);

    inline proc documentIdPool(idx: int): DocumentIdPoolBank {
      select idx {
        when 0 do return documentIdPool0;
        when 1 do return documentIdPool1;
        when 2 do return documentIdPool2;
        when 3 do return documentIdPool3;
      }
      halt("unhandled document id pool index");
      return nil;
    }

    inline proc getDocumentIdPoolEntry(poolIndex: DocIdPoolIndex): DocumentIdPoolBankEntry {
      var (poolBankIndex, poolBankSubIndex, entryIndex, entryPos) = splitDocumentIdPoolIndex(poolIndex);
      return documentIdPool(poolBankIndex).subPool[poolBankSubIndex].entries[entryIndex];
    }

    inline proc getDocumentIdPoolEntryDocId(poolIndex: DocIdPoolIndex): DocId {
      var (poolBankIndex, poolBankSubIndex, entryIndex, entryPos) = splitDocumentIdPoolIndex(poolIndex);
      return documentIdPool(poolBankIndex).subPool[poolBankSubIndex].entries[entryIndex].documentIds[entryPos];
    }

    proc allocateNewDocIdInDocumentIdPool(docId: DocId): DocIdPoolIndex {
      var pool = documentIdPool[0]; // always start new allocations on pool 0

      pool.entryCount += 1;

      var entryIndex: uint(32) = pool.entryCount: uint(32) % pool.subPoolEntryCount;
      if (entryIndex == 0) {
        pool.subPoolIndex += 1;
        pool.subPool[pool.subPoolIndex] = new DocumentIdPoolBankSubPool(pool.bankSize, pool.subPoolEntryCount);
      }

      var entry = new DocumentIdPoolBankEntry(pool.bankSize);
      entry.documentIds[0] = docId;
      pool.subPool[pool.subPoolIndex].entries[entryIndex] = entry;

      return assembleDocumentIdPoolIndex(0, pool.subPoolIndex: uint(32), entryIndex, 0);
    }

    proc setDocIdAtNextDocumentIdPoolIndex(poolIndex: DocIdPoolIndex, docId: DocId): DocIdPoolIndex {
      var (poolBankIndex, poolBankSubIndex, entryIndex, entryPos) = splitDocumentIdPoolIndex(poolIndex);
      
      var pool = documentIdPool(poolBankIndex);

      entryPos += 1;

      if (entryPos >= pool.bankSize) {
        // if adding a new doc id to the current pool will cause a new entry, 
        // then we should bump to the next pool size
        if (poolBankIndex < 3) {
          poolBankIndex += 1;
          pool = documentIdPool(poolBankIndex);
        }

        pool.entryCount += 1;

        entryIndex = pool.entryCount: uint(32) % pool.subPoolEntryCount;
        if (entryIndex == 0) {
          pool.subPoolIndex += 1;
          pool.subPool[pool.subPoolIndex] = new DocumentIdPoolBankSubPool(pool.bankSize, pool.subPoolEntryCount);
        }

        if (pool.subPool[pool.subPoolIndex] == nil) {
          halt("pool.subPool[pool.subPoolIndex] == nil ", poolIndex, " ", poolBankIndex, " ", poolBankSubIndex, " ", entryIndex, " ", entryPos);
        }

        pool.subPool[pool.subPoolIndex].entries[entryIndex] = new DocumentIdPoolBankEntry(pool.bankSize, poolIndex);

        poolBankSubIndex = pool.subPoolIndex: uint(32);
        entryPos = 0;
      }

      pool.subPool[poolBankSubIndex].entries[entryIndex].documentIds[entryPos] = docId;

      return assembleDocumentIdPoolIndex(poolBankIndex, poolBankSubIndex, entryIndex, entryPos);
    }

    proc addTermForDocument(term: Term, docId: DocId): TermEntryPoolIndex {
      var poolIndex: TermEntryPoolIndex;

      var entry = getTerm(term);
      if (entry == nil) {
        // no term in this table position, allocate a new term in the term pool
        entry = new TermEntry(term, termHashTable[tableIndexForTerm(term)].read());
        poolIndex = allocateNewDocIdInDocumentIdPool(docId);
        entry.lastDocIdIndex.write(poolIndex);
        var entryIndex = setTermEntryAtNextTermEntryPoolIndex(entry);
        termHashTable[tableIndexForTerm(term)].write(entryIndex);
      } else {
        poolIndex = setDocIdAtNextDocumentIdPoolIndex(entry.lastDocIdIndex.read(), docId);
        entry.lastDocIdIndex.write(poolIndex);
      }
      entry.documentIdCount.add(1);

      return poolIndex;
    }

    proc getTerm(term: Term): TermEntry {
      // iterate through the entries at this table position
      var entryIndex = termHashTable[tableIndexForTerm(term)].read();
      while (entryIndex != 0) {
        var entry = getTermEntryPoolEntry(entryIndex);
        if (entry.term == term) {
          return entry;
        }
        entryIndex = entry.next.read();
      }
      return nil;
    }

    proc addDocument(terms: [?D] IndexTerm, externalDocId: ExternalDocId): bool {
      if (isSegmentFull()) {
        // segment is full:
        // upon segment full, the segment manager should
        //    create a new segment
        //    append this to the new one
        //    flush the segment in the background
        //    replace this in-memory segment with a segment that references disk
        return false;
      }

      // store the external document id and map it to our internal document index
      // NOTE: this assumes we are going to succeed in adding the document
      var documentIndex = documentCount.read();

      externalDocumentIds[documentIndex] = externalDocId;

      for term in terms {
        var docId = assembleDocId(documentIndex, term.textLocation);
        addTermForDocument(term.term, docId);
      }

      documentCount.add(1);
 
      return true;
    }

    iter query(query: Query): QueryResult {
      // Since documents may be being added to the index while we query the index,
      // we need a stable view of the index that prevents partial results.
      // To do so, we capture current document index.
      // Any documents added to the index after this capture will be ignored for this call.
      var readerMaxDocumentIndex = documentCount.read();

      var op = chasm_interpret(this, query.instructionBuffer);
      if (op != nil) {
        for opValue in op.evaluate() {
          var docId = opValue: uint(32);
          var (documentIndex, textLocation) = splitDocId(docId); 
          if (documentIndex <= readerMaxDocumentIndex) {
            var term = (opValue >> 32): uint(32);
            yield new QueryResult(term, textLocation, externalDocumentIdFromDocumentIndex(documentIndex));
          }
        }
      }
    }

    proc operandForTerm(term: Term): Operand {
      var entry = getTerm(term);
      return if (entry != nil) then new TermEntryOperand(this, entry) else NullOperand[here.id];
    }
  }
}