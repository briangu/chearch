use GenHashKey64, Logging, Memory, IO, Partitions, Time;

config const default_lfh_size: uint = 1024 * 64;
config const max_doc_node_size = 1024 * 64;

class DocumentNode {

  // controls the size of this document list
  var listSize: int = 1;

  var next: DocumentNode;

  // list of documents
  var documents: [0..listSize-1] DocId;

  // number of documents in this node's list
  var documentCount: atomic int;

  // Gets the document id index to use to add a new document id.  documentCount should be incremented after using this index.
  proc documentIdIndex() {
    return documents.size - documentCount.read() - 1;
  }

  proc nextDocumentIdNodeSize() {
    if (documents.size >= max_doc_node_size) {
      return documents.size;
    } else {
      return documents.size * 2;
    }
  }
}

record TableEntry {
  var hashKey: atomic uint;
  var word: string; // HACK: the use of .word is buggy! just for a test until fixed
  var count: atomic int;
  var docNode: DocumentNode;
}

class LockFreeHash {
  var hashSize: uint = 1024 * 64; // must be power of 2

  var array: [0..hashSize-1] TableEntry;

  proc addWord(word: string): bool {
    var hashKey: uint = genHashKey(word);
    var idx: uint = hashKey;
    var count: uint = 0;
    
    debug("word: ", word, " count: ", count);

    while (count < array.size) {
      idx &= hashSize - 1;

      debug("idx: ", idx);

      var probedKey = array[idx].hashKey.read();
      debug("probedKey: ", probedKey);
      // HACK: the use of .word is buggy! just for a test until fixed
      if (probedKey != hashKey || array[idx].word != word) {
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

        array[idx].word = word;
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

  proc getEntry(word: string, ref entry: TableEntry): bool {
    var count: uint = 0;

    debug("word: ", word, "count ", count);

    var hashKey: uint = genHashKey(word);
    var idx: uint = hashKey;

    while (count < array.size) {
      idx &= hashSize - 1;

      var probedKey = array[idx].hashKey.read();
      if (probedKey == hashKey && array[idx].word == word) {
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

class PartitionInfo {
  var words: LockFreeHash = new LockFreeHash(default_lfh_size);
  var count: atomic int;
}

class WordIndex {
  var wordIndex: [0..Partitions.size-1] PartitionInfo;

  proc WordIndex() {
    for i in wordIndex.domain {
      on Partitions[i] {
        wordIndex[i] = new PartitionInfo();
      }      
    }
  }

  proc addWord(word: string, docId: DocId) {
    var partition = partitionForWord(word);
    var info = wordIndex[partition];
    on info {
      // find word in word list
      var entry: TableEntry;
      var found = info.words.getEntry(word, entry);
      
      // if word is not present then add it
      if (found) {
        var added = info.words.addWord(word);
        if (!added) {
          error("could not add word ", word);
        }
        found = info.words.getEntry(word, entry);
      }

      if (found) {
        // add document to word node

        // increment counters
        entry.count.add(1);
        info.count.add(1);
      }
    }
  }
}

proc main() {
  initPartitions();

  var wordIndex = new WordIndex();

  var t: Timer;
  t.start();

  var infile = open("words.txt", iomode.r);
  var reader = infile.reader();
  var word: string;
  var docId = 0;
  while (reader.readln(word)) {
    wordIndex.addWord(word, docId);
    docId = (docId + 1) % 1000; // fake document ids
  }

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
