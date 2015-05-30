module Indexer {

  use Logging, Partitions, Search, Time;
  
  config const buffersize = 1024;
  config const testAfterIndex: bool = true;
  config const batchSize = 128;

  class IndexRequest {
    var word: string;
    var docId: DocId;
  }

  class PartitionIndexer {
    var partition: int;
    var buff$: [0..buffersize-1] sync IndexRequest;
    var bufferIndex: atomic int;
    var release$: single bool;
    var t: Timer;

    proc PartitionIndexer() {
      partition = 0;
      // via nextBufferIndex, this is incremented to zero before first use
      bufferIndex.write(-1);
    }

    proc PartitionIndexer(idx: int) {
      partition = idx;
      // via nextBufferIndex, this is incremented to zero before first use
      bufferIndex.write(-1);
    }

    proc startConsumer() {
      begin {
        consumer();
      }
    }

    proc nextBufferIndex(): int {
      var idx: int;
      var success = false;
      while (!success) { 
        var originalValue = bufferIndex.read();
        idx = (originalValue + 1) % buffersize;
        success = bufferIndex.compareExchange(originalValue, idx);
      }
      return idx;
    }

    proc enqueueIndexRequest(word: string, docId: DocId) {
      var indexRequest = new IndexRequest(word, docId);
      const idx = nextBufferIndex();
      buff$(idx).writeEF(indexRequest);
      debug("enqueuing ", indexRequest);
    }

    proc waitForIndexer() {
      debug("waiting...");
      release$;
      debug("done waiting...");
    }

    proc markCompleteForIndexer() {
      debug("marking for completion");
      const idx = nextBufferIndex();
      buff$(idx).writeEF(nil);
      debug("halting consumer");
    }

    proc flushBatch(batch: [] IndexRequest, batchCount: int) {
      t.start();
      debug("flushing batch");
      indexWordsOnPartition(batch, batchCount, partition);
      t.stop();
      timing("flushed ", batchCount," batch in ",t.elapsed(TimeUnits.microseconds), " microseconds");

      t.start();
      for i in 0..batchCount-1 {
        if (testAfterIndex) {
          var entry = entryForWord(batch[i].word);
          if (entry == nil || entry.word != batch[i].word) {
            error("indexer: failed to index word ", batch[i].word);
            exit(0);
          }
        }
        delete batch[i];
      }
      t.stop();
      timing("test fetch in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    }

    proc consumer() {
      var batch: [0..batchSize-1] IndexRequest;
      var batchCount = 0;

      for indexRequest in readFromBuff() {
        debug("adding ", indexRequest, " to batch");
        batch[batchCount] = indexRequest;
        batchCount += 1;

        if (batchCount == batch.size) {
          flushBatch(batch, batchCount);
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        flushBatch(batch, batchCount);
      }
    }

    iter readFromBuff() {
      var ind = 0;
      var nextVal = buff$(ind);

      while (nextVal != nil) {
        yield nextVal;

        ind = (ind + 1) % buffersize;
        nextVal = buff$(ind);
      }

      release$ = true;
    }
  }

  var indexers: [0..Partitions.size-1] PartitionIndexer;

  proc initIndexer() {
    var t: Timer;
    t.start();
    for i in 0..Partitions.size-1 {
      on Partitions[i] {
        indexers[i] = new PartitionIndexer(i);
        indexers[i].startConsumer();
      }
    }
    t.stop();
    timing("initialized indexer in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc indexerForWord(word: string): PartitionIndexer {
    return indexers[partitionForWord(word)];
  }

  proc enqueueIndexRequest(word: string, docId: DocId) {
    var indexRequest = new IndexRequest(word, docId);
    debug("enqueuing ", indexRequest);
    var indexer = indexerForWord(word);
    // TODO: do we need to go onto the indexer locale for this?  or will it just automatically be on that locale?
    on indexer {
      indexer.enqueueIndexRequest(word, docId);
    }
  }

  proc waitForIndexer() {
    markCompleteForIndexer();
    debug("waiting...");
    for indexer in indexers {
      // TODO: do we need to do this on the locale? or can we just call waitForIndexer and have it work?
      on indexer {
        indexer.waitForIndexer();
      }
    }
    debug("done waiting...");
  }

  proc markCompleteForIndexer() {
    debug("marking for completion");
    for indexer in indexers {
      // TODO: do we need to do this on the locale? or can we just call waitForIndexer and have it work?
      on indexer {
        indexer.markCompleteForIndexer();
      }
    }
    debug("halting consumer");
  }
}