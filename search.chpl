module Search {
  
  use Logging, Common, Memory, GenHashKey64, Partitions, Time;

  config const dir_prefix = "/ssd/words";
  config const use_partition_in_name: bool = false;
  config const entry_size: uint = 1024 * 64;
  config const max_doc_node_size: uint = 1024 * 32;

  class DocumentIdNode {

    // controls the size of this document list
    var listSize: uint = 1;

    var next: DocumentIdNode;

    // list of documents
    var documents: [0..listSize-1] DocId;

    // number of documents in this node's list
    var documentCount: atomic uint;

    // Gets the document id index to use to add a new document id.  documentCount should be incremented after using this index.
    proc documentIdIndex() {
      return listSize - documentCount.read() - 1;
    }

    proc nextDocumentIdNodeSize() {
      if (documents.size >= max_doc_node_size) {
        return listSize;
      } else {
        return listSize * 2;
      }
    }
  }

  record Entry {
    var hashKey: atomic uint;
    var word: string; // HACK: the use of .word is buggy! just for a test until fixed
    var documentCount: atomic uint;
    var documentIdNode: DocumentIdNode;
    var score: real;
  }

  class WordHash {
    var hashSize: uint = 1024 * 64; // must be power of 2

    var array: [0..hashSize-1] Entry;

    proc addWord(word: string, docId: DocId): bool {
      var hashKey: uint = genHashKey(word);
      var idx: uint = hashKey;
      var count: uint = 0;
      
      debug("word: ", word, " count: ", count);

      while (count < array.size) {
        idx &= hashSize - 1;

        debug("idx: ", idx);

        var probedKey = array[idx].hashKey.read();
        debug("probedKey: ", probedKey);
        if (probedKey != hashKey) {
          // The entry was either free, or contains another key.
          if (probedKey != 0) {
            idx += 1;
            count += 1;
            continue; // Usually, it contains another key. Keep probing.
          }

          // The entry was free. Now let's try to take it using a CAS.
          var stored = array[idx].hashKey.compareExchange(0, hashKey);
          debug("stored: ", stored);
          if (!stored) {
            idx += 1;
            count += 1;
            continue;       // Another thread just stole it from underneath us.
          }

          // Either we just added the key, or another thread did.
          var documentIdNode = new DocumentIdNode();
          documentIdNode.documents[documentIdNode.documentIdIndex()] = docId;
          documentIdNode.documentCount.write(1);

          array[idx].word = word;
          array[idx].documentIdNode = documentIdNode;
          array[idx].documentCount.write(1);
        }

        // Store the value in this array entry.
        // array[idx].value.write(value);
        return true;
      }

      if (count == array.size) {
        // out of capacity
        error("hash out of capacity");
      }

      return false;
    }

    proc appendDocId(word: string, docId: DocId): bool {
      var count: uint = 0;

      debug("word: ", word, "count ", count);

      var hashKey: uint = genHashKey(word);
      var idx: uint = hashKey;

      while (count < array.size) {
        idx &= hashSize - 1;

        var probedKey = array[idx].hashKey.read();
        if (probedKey == hashKey) {
          debug("found match for hashKey");

          var docNode = array[idx].documentIdNode;
          var docCount = docNode.documentCount.read();
          if (docCount < docNode.listSize) {
            docNode.documents[docNode.documentIdIndex()] = docId;
            docNode.documentCount.add(1);
          } else {
            docNode = new DocumentIdNode(docNode.nextDocumentIdNodeSize(), docNode);
            debug("adding new document id node of size ", docNode.listSize);
            docNode.documents[docNode.documentIdIndex()] = docId;
            docNode.documentCount.write(1);
            array[idx].documentIdNode = docNode;
          }
          array[idx].documentCount.add(1);
          
          return true;
        }
        if (probedKey == 0) {
          return false;
        }

        idx += 1;
        count += 1;

        debug("probedKey: ", probedKey, " count: ", count);
      }

      debug("exhuastive search and key not found");

      return false;
    }

    // returns a COPY of the record, not the actual record. i.e., updates to documentIdNode will not reflex in the hash.
    proc getEntry(word: string, ref entry: Entry): bool {
      var count: uint = 0;

      debug("word: ", word, "count ", count);

      var hashKey: uint = genHashKey(word);
      var idx: uint = hashKey;

      while (count < array.size) {
        idx &= hashSize - 1;

        var probedKey = array[idx].hashKey.read();
        if (probedKey == hashKey) {
          debug("found match for hashKey");
          entry = array[idx];
          return true;
        }
        if (probedKey == 0) {
          return false;
        }

        idx += 1;
        count += 1;

        debug("probedKey: ", probedKey, " count: ", count);
      }

      debug("exhuastive search and key not found");

      return false;
    }
  }

  class PartitionIndex {
    var partition: int;
    var entryCount: atomic uint;
    var entryIndex = new WordHash(entry_size);

    proc PartitionIndex() {
      partition = 0;
    }

    proc PartitionIndex(idx: int) {
      partition = idx;
    }
  }

  var Indices: [0..Partitions.size-1] PartitionIndex;

  proc initIndices() {
    var t: Timer;
    t.start();

    // create one index per partition
    for partition in 0..Partitions.size-1 {
      on Partitions[partition] {
        info("index [", partition, "] is mapped to partition ", partition);
        // allocate the partition index on the partition locale
        Indices[partition] = new PartitionIndex(partition);
      }
    }
    t.stop();
    timing("initialized indices in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc initIndicesFromPartitionDisks() {
    var t: Timer;
    t.start();
    coforall partition in 0..Partitions.size-1 {
      on Partitions[partition] {
        info("index [", partition, "] is loading on partition ", partition);
  
        // allocate the partition index on the partition locale
        var partitionIndex = new PartitionIndex(partition);
  
        var name: string = dir_prefix;
        if (use_partition_in_name) {
          name += partition;
        }
        name += ".txt";
        var infile = open(name, iomode.r);
        var reader = infile.reader();
        var word: string;
        var docId: DocId;
        while (reader.read(word) && reader.read(docId)) {
          debug(word, "\t\t", docId);
          local {
            indexWordOnPartition(word, docId, partitionIndex);
          }
        }

        Indices[partition] = partitionIndex;
  
        info("index [", partition, "] finished loading");
      }
    }
    t.stop();
    timing("initialized indices in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  inline proc indexContainsWord(word: string, partitionIndex: PartitionIndex): bool {
    var entry: Entry;
    return entryIndexForWord(word, partitionIndex, entry);
  }

  inline proc entryForWordOnPartition(word: string, partitionIndex: PartitionIndex, ref entry: Entry): bool {
    return partitionIndex.entryIndex.getEntry(word, entry);
  }

  proc entryForWord(word: string, ref entry: Entry): bool {
    var partition = partitionForWord(word);
    var partitionIndex = Indices[partition];
    var found: bool;
    on partitionIndex {
      found = entryForWordOnPartition(word, partitionIndex, entry);
    }
    return found;
  }

  proc indexWord(word: string, docId: DocId): bool {
    var partition = partitionForWord(word);
    var partitionIndex = Indices[partition];
    var success: bool;
    on partitionIndex {
      success = indexWordOnPartition(word, docId, partitionIndex);
    }
    return success;
  }

  proc indexWordsOnPartition(requests: [] IndexRequest, requestCount: int, partition: int) {
    var partitionIndex = Indices[partition];
    var success: bool = true;
    on partitionIndex {
      for i in 0..requestCount-1 {
        success = success && indexWordOnPartition(requests[i].word, requests[i].docId, partitionIndex);
      }
    }
    return success;
  }

  proc indexWordOnPartition(word, docId, partitionIndex: PartitionIndex): bool {
    var entry: Entry;
    var found = entryForWordOnPartition(word, partitionIndex, entry);
    if (found) {
      debug("adding ", word, " to existing entries on partition ", partitionIndex.partition);
      partitionIndex.entryIndex.appendDocId(word, docId);
    } else {
      debug("adding new entry ", word , " on partition ", partitionIndex.partition);
      found = partitionIndex.entryIndex.addWord(word, docId);
      if (!found) {
        error("indexWord: failed to index ", word);
        // exit(0);
        // TODO: how do we accumuate per-partition indexing errors for a final response?
        return false;
      }
    }
    return true;
  }

  // SUPER SLOW
  proc documentIdsForWord(word: string): domain(DocId) {
    var dom: domain(DocId);
    on Partitions[partitionForWord(word)] {
      var entry: Entry;
      var found = entryForWord(word, entry); 
      if (found) {
        var node = entry.documentIdNode;
        while (node != nil) {
          var startIdx = node.listSize - node.documentCount.read();
          dom += node.documents[startIdx..node.listSize-1];
          node = node.next;
        }
      }
    }
    return dom;
  }

  iter documentIdsForEntry(entry: Entry) {
    var node = entry.documentIdNode;
    while (node != nil) {
      var startIdx = node.listSize - node.documentCount.read();
      for i in startIdx..node.listSize-1 {
        yield node.documents[i];
      }
      node = node.next;
    }
  }

  proc dumpEntry(entry: Entry) {
    on entry {
      info("word: ", entry.word, " score: ", entry.score);
      var count: uint = 0;
      for docId in documentIdsForEntry(entry) {
        writeln("\t", docId);
        count += 1;
      }
      if (count != entry.documentCount.read()) {
        error("ERROR: documentCount != count => ", count, " != ", entry.documentCount.read());
      }
    }
  }

  proc dumpPartition(partition: int) {
    var partitionIndex = Indices[partition];
    on partitionIndex {
      info("entries on partition (", partition, ") locale (", here.id, ") ", partitionIndex);

      // var word: string;
      // for i in 0..partitionIndex.entryCount.read()-1 {
      //   var entry = partitionIndex.entries[i];
      //   info("word: ", entry.word);
      //   dumpPostingTableForWord(entry.word);
      // }
    }
  }

  proc dumpPostingTableForWord(word: string) {
    var entry: Entry;
    var found = entryForWord(word, entry);
    if (found) {
      dumpEntry(entry);
    } else {
      error("word (", word, ") is not in the index");
    }
  }
}
