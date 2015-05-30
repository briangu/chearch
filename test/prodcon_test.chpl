use Logging, IO, Partitions;

class IndexRequest {
  var word: string;
}

config const buffersize = 2;

class PartitionIndexer {
  var buff$: [0..buffersize-1] sync IndexRequest;
  var bufferIndex: atomic int;
  var release$: single bool;

  proc PartitionIndexer() {
    bufferIndex.write(-1); // it's incremented to zero before first use
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

  proc enqueueIndexRequest(word: string) {
    var indexRequest = new IndexRequest(word);
    const idx = nextBufferIndex();
    writeln("enqueueIndexRequest ",word," start idx = ", idx);
    buff$(idx).writeEF(indexRequest);
    writeln("enqueueIndexRequest ",word," written idx = ", idx);
    info("enqueuing ", indexRequest);
  }

  proc waitForIndexer() {
    writeln("waiting...");
    release$;
    writeln("done waiting...");
  }

  proc markCompleteForIndexer() {
    // writeln("marking for completion");
    const idx = nextBufferIndex();
    writeln("markCompleteForIndexer start for idx = ", idx);
    buff$(idx).writeEF(nil);
    writeln("markCompleteForIndexer written for idx = ", idx);
    info("halting consumer");
  }

  proc consumer() {
    for indexRequest in readFromBuff() {
      writeln("Indexing: ", indexRequest, "...");
      // do work here
      delete indexRequest;
    }
    writeln("consumer done");
  }

  iter readFromBuff() {
    var ind = 0;
    var nextVal = buff$(ind);

    while (nextVal != nil) {
      yield nextVal;

      ind = (ind + 1) % buffersize;
      writeln("readFromBuff start ind = ", ind);
      nextVal = buff$(ind);
      writeln("readFromBuff read ind = ", ind);
    }

    writeln("readFromBuff done");

    release$ = true;
  }
}

var indexers: [0..Partitions.size-1] PartitionIndexer;

proc initIndexer() {
  for i in 0..Partitions.size-1 {
    on Partitions[i] {
      indexers[i] = new PartitionIndexer();
      indexers[i].startConsumer();
    }
  }
}

proc indexerForWord(word: string): PartitionIndexer {
  return indexers[partitionForWord(word)];
}

proc enqueueIndexRequest(word: string) {
  var indexRequest = new IndexRequest(word);
  info("enqueuing ", indexRequest);
  var indexer = indexerForWord(word);
  // TODO: do we need to go onto the indexer locale for this?  or will it just automatically be on that locale?
  // on indexer {
    indexer.enqueueIndexRequest(word);
  // }
}

proc waitForIndexer() {
  markCompleteForIndexer();
  for indexer in indexers {
    // TODO: do we need to do this on the locale? or can we just call waitForIndexer and have it work?
    // on indexer {
      indexer.waitForIndexer();
    // }
  }
}

proc markCompleteForIndexer() {
  for indexer in indexers {
    // TODO: do we need to do this on the locale? or can we just call waitForIndexer and have it work?
    // on indexer {
      indexer.markCompleteForIndexer();
    // }
  }
  info("halting consumer");
}

proc main() {
  initPartitions();
  initIndexer();

  var infile = open("words.txt", iomode.r);
  var reader = infile.reader();
  var word: string;
  while (reader.readln(word)) {
    enqueueIndexRequest(word);
  }

  waitForIndexer();
}
