module Search {

  use Logging, Memory, GenHashKey32, ReplicatedDist, Time;

  /**
    A document id is the connection between a term and the external document it belongs to,
    providing both a reference to the external document as well as the term's text position within that document.

    Since segments have a fixed upper-bound of documents, the document id can easily fit both the internal, relative,
    document id and the text position with in that document.

    The 64-bit unsigned integer is partitioned as follows:
      high-order 32-bits: index into segment's documents array
      low-order 32-bits: text position in external document
  */
  type DocId = uint(64);

  inline proc documentIndexFromDocId(docId: DocId): uint {
    return (docId >> 32): uint;
  }

  inline proc textLocationFromDocId(docId: DocId): uint(32) {
    return (docId & (0xFFFFFFFF << 32)): uint(32); // TODO: can we just cast it to a uint(32)?
  }

  // Separate the search parition strategy from locales.
  // The reason that it's worth keeping partitions separate from locales is that
  // it makes it easy to change locale counts without having to rebuild the partitions.
  //
  // Number of dimensions in the partition space.
  // Each partition will be projected to a locale.
  // If the number of partitions exceeds the number of locales,
  // then the locales will be over-subscribed with possibly more than one
  // partition per locale.
  //
  config const partitionCount = 16;

  config const maxDocumentIdNodeSize: uint = 1024 * 32;

  // NOTE: documentsPerSegment must fit in an unsigned 32-bit integer
  config const documentsPerSegment: uint = 1024 * 512;

  config const termHashTableSize: uint = 1024 * 32;

  class DocumentIdNode {

    // controls the size of this document list
    var nodeSize: uint = 1;

    var next: DocumentIdNode;

    // list of documents
    var documentIds: [0..nodeSize-1] DocId;

    // number of documents in this node's list
    var documentIdCount: atomic uint;

    // Gets the document id index to use to add a new document id.  documentCount should be incremented after using this index.
    proc documentIdIndex() {
      return nodeSize - documentIdCount.read() - 1;
    }

    proc nextDocumentIdNodeSize() {
      if (documentIds.size >= maxDocumentIdNodeSize) {
        return nodeSize;
      } else {
        return nodeSize * 2;
      }
    }
  }

  type OperandValue = uint;

  class Operand {
    proc hasValue(): bool {
      return false;
    }

    proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("iterated too far");
      }
      return 0;
    }

    proc advance() {
      if (!hasValue()) {
        halt("iterated too far");
      }
    }

    iter evaluate() {
      while (hasValue()) {
        yield getValue();
        advance();
      }
    }
  }

  class UnionOperand : Operand {
    var opA: Operand;
    var opB: Operand;
    var curOp: Operand = nextOperand();

    proc nextOperand(): Operand {
      var op: Operand = nil;

      if (opA.hasValue() && opB.hasValue()) {
        if (opA.getValue() > opB.getValue()) {
          op = opA;
        } else if (opA.getValue() == opB.getValue()) {
          opB.advance(); // skip over duplicate value
          op = opA;
        } else {
          op = opB;
        }
      } else if (opA.hasValue()) {
        op = opA;
      } else if (opB.hasValue()) {
        op = opB;
      }

      return op;
    }

    proc hasValue(): bool {
      return curOp != nil;
    }

    proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("union iterated past end of operands ", opA, opB);
      }

      return curOp.getValue();
    }

    proc advance() {
      if (!hasValue()) {
        halt("union iterated past end of operands ", opA, opB);
      }

      curOp.advance();
      curOp = nextOperand();
    }
  }

  class IntersectionOperand : Operand {
    var opA: Operand;
    var opB: Operand;
    var curOp: Operand = nextOperand();

    proc nextOperand(): Operand {
      var op: Operand = nil;

      while(opA.hasValue() && opB.hasValue()) {
        if (opA.getValue() > opB.getValue()) {
          opA.advance();
        } else if (opA.getValue() == opB.getValue()) {
          opB.advance(); // skip over duplicate value
          op = opA;
          break;
        } else { // A > B
          opB.advance();
        }
      }

      return op;
    }

    proc hasValue(): bool {
      return curOp != nil;
    }

    proc getValue(): OperandValue {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      return curOp.getValue();
    }

    proc advance() {
      if (!hasValue()) {
        halt("intersection iterated past end of operands ", opA, opB);
      }

      curOp = nextOperand();
    }
  }

  class TermEntryOperand: Operand {
    var term: TermEntry;
    var node: DocumentIdNode;
    var nodeIdx: uint = node.nodeSize - node.documentIdCount.read();

    inline proc hasValue(): bool {
      return node != nil;
    }

    proc docId(): DocId {
      if (!hasValue()) {
        halt("iterated past end of document ids", term);
      }

      return node.documentIds[nodeIdx];
    }

    proc documentIndex(): uint {
      return documentIndexFromDocId(docId());
    }

    proc getValue(): OperandValue {
      var x = documentIndex();
      return x;
    }

    proc advance() {
      if (!hasValue()) {
        halt("iterated past end of document ids", term);
      }

      // skip duplicates
      var currentValue = getValue();
      while (hasValue() && (getValue() == currentValue)) {
        nodeIdx += 1;
        if (nodeIdx >= node.nodeSize) {
          node = node.next;
          nodeIdx = 0;
        }
      }
    }
  }

  class TermEntry {
    var term: string;

    // pointer to the node which has the most recently index documents
    var head: DocumentIdNode;

    // next term in the bucket chain
    var next: TermEntry;

    // NOTE: this is a temporary solution.
    //       we can remove the lock if we can figure out how to use exlusive read / writes on the head pointer
    //       or we can redesign the datastructure design to use atomit int's everywhere (may happen anyway for other reasons)
    var headLock: atomicflag;

    inline proc lockHead() {
      while headLock.testAndSet() do chpl_task_yield();
    }

    inline proc unlockHead() {
      headLock.clear();
    }

    // max document id in the document id node chain.
    // Any document id found during a read must be less-than-equal to this id.
    // if it is greather-than, then document is being currently indexed.
    var maxDocumentId: atomic uint;

    // total number of documents this term appears in
    var documentIdCount: atomic uint;

    // keep track of read count to perform Move-To-Front optimization
    var readCount: atomic uint;

    iter documentIds() {
      headLock();
      var node = head;
      headUnlock(); 
      while (node != nil) {
        var startIdx = node.nodeSize - node.documentIdCount.read();
        for id in node.documentIds[startIdx..node.nodeSize-1] {
          yield node.documentIds[id];
        }
        node = node.next;
      }
    }

    proc getAsOperand(): TermEntryOperand {
      var documentIdNode: DocumentIdNode;
      // UGH.
      headLock();
      documentIdNode = head;
      headUnlock(); 
      return new TermEntryOperand(this, documentIdNode);
    }
  }

  record TermHashTableEntry {
    var head: TermEntry;

    // NOTE: this is a temporary solution, as it will hurt performance under "hot keys".
    //       we can remove the lock if we can figure out how to use exlusive read / writes on the head pointer
    //       or we can redesign the datastructure design to use atomit int's everywhere (may happen anyway for other reasons)
    var headLock: atomicflag;

    inline proc lockHead() {
      while headLock.testAndSet() do chpl_task_yield();
    }

    inline proc unlockHead() {
      headLock.clear();
    }
  }

  // A segment is a set of documents that can be searched over.
  // TODO: document deletes are not supported
  // TODO: document updates are not supported
  class Segment {

    // map from internal document id to external document id
    var documents: [0..documentsPerSegment-1] uint;

    var documentCount: atomic uint(32);

    // current maximum document id for all terms
    var maxDocumentId: atomic uint;

    var termHashTable: [0..termHashTableSize-1] TermHashTableEntry;

    inline proc tableIndexForTerm(term: string): uint {
      return genHashKey32(term) % termHashTable.size: uint(32);
    }

    inline proc isSegmentFull(): bool {
      return documentIndexFromDocId(maxDocumentId.read()) >= documents.size;
    }

    inline proc documentFromDocId(docId: DocId): uint {
      return documents[documentIndexFromDocId(maxDocumentId.read())];
    }

    inline proc splitDocId(docId: DocId): (uint, uint(32)) {
      return (documentIndexFromDocId(docId), textLocation(docId));
    }

    inline proc createDocId(documentIndex: uint(32), textLocation: uint(32)): DocId {
      return ((documentIndex: DocId) << 32) | (textLocation: DocId);
    }

    proc addTermForDocument(term: string, docId: DocId) {
      var entry = getTerm(term);
      if (entry == nil) {
        // no term in this table position, so need to add one

        // TODO: insert at tail
        var documentIdNode = new DocumentIdNode();
        var tableEntry = termHashTable[tableIndexForTerm(term)];
        tableEntry.lockHead();
        entry = new TermEntry(term, documentIdNode, tableEntry.head);
        termHashTable[tableIndexForTerm(term)].head = entry;
        tableEntry.unlockHead();
      }

      entry.lockHead();
      var docNode = entry.head;
      entry.unlockHead();
      var docCount = docNode.documentIdCount.read();
      if (docCount < docNode.nodeSize) {
        docNode.documentIds[docNode.documentIdIndex()] = docId;
        docNode.documentIdCount.add(1);
      } else {
        docNode = new DocumentIdNode(docNode.nextDocumentIdNodeSize(), docNode);
        debug("adding new document id node of size ", docNode.nodeSize);
        docNode.documentIds[docNode.documentIdIndex()] = docId;
        docNode.documentIdCount.write(1);
        entry.lockHead();
        entry.head = docNode;
        entry.unlockHead();
      }

      entry.documentIdCount.add(1);
      entry.maxDocumentId.write(docId);

      debug(entry);
    }

    proc getTerm(term: string): TermEntry {
      // iterate through the entries at this table position
      var tableEntry = termHashTable[tableIndexForTerm(term)];
      tableEntry.lockHead();
      var entry = tableEntry.head;
      tableEntry.unlockHead();
      while (entry != nil) {
        if (entry.term == term) {
          return entry;
        }
        entry = entry.next;
      }
      return nil;
    }

    proc addDocument(terms: [?D] IndexTerm, externalDocId: uint): bool {
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
      var documentIndex = documentCount.fetchAdd(1);

      documents[documentIndex] = externalDocId;

      for term in terms {
        var docId = createDocId(documentIndex, term.textLocation);
        addTermForDocument(term.term, docId);
        maxDocumentId.write(docId);
      }
 
      return true;
    }

    proc query(query: Query, ref results: [?D] QueryResult) {
      // Capture maxDocId.  Any documents added to the index after this capture will be ignored for this call.
      var readerMaxDocId = maxDocumentId.read();

      // ignore all docIds > readerMaxDocId
      // writeln("running query on loc ", here.id);
      var termA = getTerm("hello");
      var termB = getTerm("world");
      var termC = getTerm("series");
      // writeln("hello: ", termA != nil, " ", "world: ", termB != nil, " ", "series: ", termC != nil);
      if (termA != nil && termB != nil && termC != nil) {
        var termAOp = new TermEntryOperand(termA);
        var termBOp = new TermEntryOperand(termB);
        var and = new IntersectionOperand(termAOp, termBOp);
        var termCOp = new TermEntryOperand(termC);
        var op = new UnionOperand(and, termCOp);
        for documentIndex in op.evaluate() {
          // LOCAL exception
          // writeln(documentIndex);
        }
      }
    }
  }

  class PartitionManager {
    var segment: Segment;

    proc addDocument(terms: [?D] IndexTerm, externalDocId: uint): bool {
      var success = segment.addDocument(terms, externalDocId);
      if (!success) {
        // TODO: handle segmentFull scenario
      }
      return success;
    }

    proc query(query: Query, ref results: [?D] QueryResult) {
      // TODO: handle multiple segments
      segment.query(query, results);
    }
  }

  class Query {
    var term: string;
  }

  class QueryResult {
    var externalDocId: uint;
    var textLocation: uint(32);
  }

  record IndexTerm {
    var term: string; // TODO: use integer ref to string table
    var textLocation: uint(32);
  }


  // Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
  const Space = {0..partitionCount-1};
  const ReplicatedSpace = Space dmapped ReplicatedDist();
  var Partitions: [ReplicatedSpace] PartitionManager;

  proc initPartitions() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        local {
          for i in Partitions.domain {
            Partitions[i] = new PartitionManager(new Segment());
          }
        }
      }
    }

    t.stop();
    timing("initialized index in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc addDocument(docHash: uint(32), terms: [?D] IndexTerm, externalDocId: uint) {
    // first move the locale that should have the document.
    on Locales[docHash % Locales.size] {
      // locally operate in the locale, which has one or more partitions.
      local {
        var mgr = Partitions[docHash % partitionCount];
        mgr.addDocument(terms, externalDocId);
      }
    }
  }

  proc query(query: Query, ref results: [?D] QueryResult) {
    // var localeResults: [Locales.domain] domain;

    coforall loc in Locales {
      on loc {
        local {
          for i in Partitions.domain {
            var mgr = Partitions[i];
            if (mgr != nil) {
              var localResults: [1] QueryResult;
              mgr.query(query, localResults);
            }
          }
        }
        // localeResults[here.id] =
      }
    }
  }
}
