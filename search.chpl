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
  config const partitionDimensions = 16;

  config const maxDocumentIdNodeSize: uint = 1024 * 32;

  // NOTE: documentsPerSegment must fit in an unsigned 32-bit integer
  config const documentsPerSegment: uint = 1024 * 1024 * 1;

  config const termHashTableSize: uint = 1024 * 32;

  class DocumentIdNode {

    // controls the size of this document list
    var nodeSize: uint = 1;

    var next: DocumentIdNode;

    // list of documents
    var documents: [0..nodeSize-1] DocId;

    // number of documents in this node's list
    var documentCount: atomic uint;

    // Gets the document id index to use to add a new document id.  documentCount should be incremented after using this index.
    proc documentIdIndex() {
      return nodeSize - documentCount.read() - 1;
    }

    proc nextDocumentIdNodeSize() {
      if (documents.size >= maxDocumentIdNodeSize) {
        return nodeSize;
      } else {
        return nodeSize * 2;
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
    var documentCount: atomic uint;

    // keep track of read count to perform Move-To-Front optimization
    var readCount: atomic uint;
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

    var termHashTable: [0..termHashTableSize-1] TermEntry;

    inline proc tableIndexForTerm(term: string): uint {
      return genHashKey32(term) % termHashTable.size;
    }

    inline proc isSegmentFull(): bool {
      return documentIndexFromDocId(maxDocumentId.read()) >= documents.size;
    }

    inline proc documentFromDocId(docId: DocId): uint {
      return documents[documentIndexFromDocId(maxDocumentId.read())];
    }

    inline proc documentIndexFromDocId(docId: DocId): uint {
      return (docId >> 32): uint;
    }

    proc textPositionFromDocId(docId: DocId): uint(32) {
      return (docId & (0xFFFFFFFF << 32)): uint(32);
    }

    inline proc createDocId(documentIndex: uint(32), textLocation: uint(32)): DocId {
      return ((documentIndex: DocId) << 32) | (textLocation: DocId);
    }

    proc addTermForDocument(term: string, docId: DocId) {
      var entry = getTerm(term);
      if (entry == nil) {
        // no term in this table position, so need to add one

        // documentIdNode.documents[documentIdNode.documentIdIndex()] = docId;
        // documentIdNode.documentCount.write(1);

        // TODO: insert at tail
        var head = termHashTable[tableIndexForTerm(term)];
        var documentIdNode = new DocumentIdNode();
        entry = new TermEntry(term, documentIdNode, head);

        // TODO: atomic needed?
        atomic {
          termHashTable[tableIndexForTerm(term)] = entry;
        }
      }

      var docNode = entry.documentIdNode;
      var docCount = docNode.documentCount.read();
      if (docCount < docNode.nodeSize) {
        docNode.documents[docNode.documentIdIndex()] = docId;
        docNode.documentCount.add(1);
      } else {
        docNode = new DocumentIdNode(docNode.nextDocumentIdNodeSize(), docNode);
        debug("adding new document id node of size ", docNode.nodeSize);
        docNode.documents[docNode.documentIdIndex()] = docId;
        docNode.documentCount.write(1);
        entry.documentIdNode = docNode;
      }

      entry.documentCount.write(1);
      entry.maxDocumentId.write(docId);
    }

    proc getTerm(term: string): TermEntry {
      // iterate through the entries at this table position
      var entry = termHashTable[tableIndexForTerm(term)];
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

      var term = "hello";
      var textPosition = 0;
      var docId = createDocId(documentCount.read(), 0);
      addTermForDocument(term, docId);

      // segment document text and infer all terms and text locations
      // update all terms in the termHashTable
      // update global maxDocId
      maxDocumentId.write(docId);

      return true;
    }

    proc query() {
      // capture maxDocId
      var readerMaxDocId = maxDocumentId.read();
      // remove all docIds > readerMaxDocId
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

    proc query() {

    }
  }

  class Index {
    
    // Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
    const Space = {0..partitionDimensions-1};
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

    inline proc partitionIdForWord(document: string): int {
      return genHashKey32(document) % partitionDimensions;
    } 

    inline proc localeForDocument(document: string): locale {
      return Locales[partitionIdForWord(document) % Locales.size];
    }

    inline proc partitionManagerForDocument(document: string): PartitionManager {
      return Partitions[partitionIdForWord(document)];
    }

    proc addDocument(document: string, externalDocId: uint) {
      // first move the locale that should have the document.
      on localeForDocument(document) {
        // locally operate on the partition
        local {
          var mgr = partitionManagerForDocument(document);
          mgr.addDocument(document, externalDocId);
        }
      }
    }

    proc query() {

    }
  }
}
