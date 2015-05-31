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
  config const documentsPerSegment: uint = 1024 * 1024 * 1;

  config const termHashTableSize: uint = 1024 * 32;

  class Query {
    var term: string;
  }

  class QueryResult {
    var externalDocId: uint;
    var textLocation: uint(32);
  }

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

  class TermEntryIterator {
    var term: TermEntry;
    var node: DocumentIdNode;
    var nodeIdx: uint;

    proc TermEntryIterator() {
      node = term.documentIdNode;
      nodeIdx = node.nodeSize - node.documentIdCount.read();
    }

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

    proc advance() {
      if (!hasValue()) {
        halt("iterated past end of document ids", term);
      }

      nodeIdx += 1;
      if (nodeIdx >= node.nodeSize) {
        node = node.next;
        nodeIdx = 0;
      }
    }
  }

  class TermEntry {
    var term: string;

    // pointer to the node which has the most recently index documents
    var documentIdNode: DocumentIdNode;

    // next term in the bucket chain
    var next: TermEntry;

    // max document id in the document id node chain.
    // Any document id found during a read must be less-than-equal to this id.
    // if it is greather-than, then document is being currently indexed.
    var maxDocumentId: atomic uint;

    // total number of documents this term appears in
    var documentIdCount: atomic uint;

    // keep track of read count to perform Move-To-Front optimization
    var readCount: atomic uint;

    iter documentIds() {
      var node = documentIdNode;
      while (node != nil) {
        var startIdx = node.nodeSize - node.documentIdCount.read();
        for id in node.documentIds[startIdx..node.nodeSize-1] {
          yield node.documentIds[id];
        }
        node = node.next;
      }
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

      var docNode = entry.documentIdNode;
      var docCount = docNode.documentIdCount.read();
      if (docCount < docNode.nodeSize) {
        docNode.documentIds[docNode.documentIdIndex()] = docId;
        docNode.documentIdCount.add(1);
      } else {
        docNode = new DocumentIdNode(docNode.nextDocumentIdNodeSize(), docNode);
        debug("adding new document id node of size ", docNode.nodeSize);
        docNode.documentIds[docNode.documentIdIndex()] = docId;
        docNode.documentIdCount.write(1);
        entry.documentIdNode = docNode;
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

    proc addDocument(document: string, externalDocId: uint): bool {
      if (isSegmentFull()) {
        // segment is full:
        // upon segment full, the segment manager should
        //    create a new segment
        //    append this to the new one
        //    flush the segment in the background
        //    replace this in-memory segment with a segment that references disk
        return false;
      }

      var t: Timer;
      t.start();

      var infile = open("words.txt", iomode.r);
      var reader = infile.reader();
      var term: string;
      var docId: DocId = 1;
      var count: uint(32) = 0;

      // store the external document id and map it to our internal document index
      // NOTE: this assumes we are going to succeed in adding the document
      var documentIndex = documentCount.fetchAdd(1);
      documents[documentIndex] = documentIndex + 100;

      while (reader.readln(term)) {
        var textLocation: uint(32) = count;
        var docId = createDocId(documentIndex, textLocation);
        addTermForDocument(term, docId);
        maxDocumentId.write(docId);

        count += 1;
        if ((count + 1) % 1000 == 0) {
          documentIndex = documentCount.fetchAdd(1);
          documents[documentIndex] = documentIndex + 100;
        }
      }

      t.stop();
      timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

      var totalTerms: uint = 0;
      for i in termHashTable.domain {
        var entry = termHashTable[i].head;
        while (entry != nil) {
          // writeln(entry);
          totalTerms += entry.documentIdCount.read();
          entry = entry.next;
        }
      }
      writeln("totalTerms: ", totalTerms);
      writeln("count: ", count);

      // segment document text and infer all terms and text locations
      // update all terms in the termHashTable
      // update global maxDocId

      return true;
    }

    inline proc sortTermsByDocumentIdCount(termA: TermEntry, termB: TermEntry): (TermEntry, TermEntry) {
      var smaller = if (termA.documentIdCount.read() < termB.documentIdCount.read()) then termA else termB;
      var larger = if (smaller == termA) then termB else termA;
      return (smaller, larger);
    }

    iter intersectDocumentIds(termA: TermEntryIterator, termB: TermEntryIterator) {
      while(termA.hasValue()) {
        var outerDocumentIndex = termB.documentIndex();
        while (termB.hasValue()) {
          var innerDocumentIndex = termB.documentIndex();
          if (outerDocumentIndex == innerDocumentIndex) {
            while (termA.hasValue() && termA.documentIndex() == outerDocumentIndex) {
              yield termA.docId();
              termA.advance();
            }
            while (termB.hasValue() && termB.documentIndex() == outerDocumentIndex) {
              yield termB.docId();
              termB.advance();
            }
          } else if (outerDocumentIndex > innerDocumentIndex) {
            termB.advance();
          } else {
            break; // let termA.advance();
          }
        }
        termA.advance();
      }
    }

    // iter unionDocumentIds(termA: TermEntry, termB, TermEntry) {
    //   var (smaller, larger) = sortTermsByDocumentIdCount(termA, termB);
    //   for docId in smaller.unionDocumentIds(larger) {
    //     yield docId;
    //   }
    // }

    proc query(query: Query, ref results: [?D] QueryResult) {
      // Capture maxDocId.  Any documents added to the index after this capture will be ignored for this call.
      var readerMaxDocId = maxDocumentId.read();

      // ignore all docIds > readerMaxDocId
      var termA = getTerm("hello");
      var termB = getTerm("world");
      var (smaller, larger) = sortTermsByDocumentIdCount(termA, termB);

      var si = new TermEntryIterator(smaller);
      var li = new TermEntryIterator(larger);
      for docId in intersectDocumentIds(si, li) {
        if (docId < readerMaxDocId) {
          //
        }
      }
      delete si;
      delete li;
    }
  }

  class PartitionManager {
    var segment: Segment;

    proc addDocument(document: string, externalDocId: uint): bool {
      var success = segment.addDocument(document, externalDocId);
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

  class Index {

    // Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
    const Space = {0..partitionCount-1};
    const ReplicatedSpace = Space dmapped ReplicatedDist();
    var Partitions: [ReplicatedSpace] PartitionManager;

    proc initPartitions() {
      var t: Timer;
      t.start();

      for loc in Locales {
        on loc {
          for i in Partitions.domain {
            Partitions[i] = new PartitionManager(new Segment());
          }
        }
      }

      t.stop();
      timing("initialized index in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    }

    inline proc partitionIdForDocument(document: string): int {
      return genHashKey32(document) % partitionCount;
    }

    inline proc localeForDocument(document: string): locale {
      return Locales[partitionIdForDocument(document) % Locales.size];
    }

    inline proc partitionManagerForDocument(document: string): PartitionManager {
      return Partitions[partitionIdForDocument(document)];
    }

    proc addDocument(document: string, externalDocId: uint) {
      // first move the locale that should have the document.
      on localeForDocument(document) {
        // locally operate in the locale, which has one or more partitions.
        local {
          var mgr = partitionManagerForDocument(document);
          mgr.addDocument(document, externalDocId);
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
}
