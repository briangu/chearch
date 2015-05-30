use Common, Logging, IO, Partitions;

config const buffersize = 1024;
config const dir_prefix = "/ssd/words";
config const use_partition_in_name: bool = false;

class PartitionIndexer {
  var partition: int;
  var indexFile: file;
  var indexWriter: channel(true, iokind.dynamic, true);

  proc PartitionIndexer(idx: int) {
    partition = idx;

    var name: string = dir_prefix;
    if (use_partition_in_name) {
      name += partition;
    }
    name += ".txt";
    info("opening ", name);
    indexFile = open(name, iomode.cwr);
    indexWriter = indexFile.writer();
  }

  proc writeEntry(indexRequest: IndexRequest) {
    indexWriter.writeln(indexRequest.word, "\t", indexRequest.docId);
  }
}

var indexers: [0..Partitions.size-1] PartitionIndexer;

proc initIndexer() {
  var t: Timer;
  t.start();
  for i in 0..Partitions.size-1 {
    on Partitions[i] {
      indexers[i] = new PartitionIndexer(i);
    }
  }
  t.stop();
  timing("initialized indexer in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}

proc indexerForWord(word: string): PartitionIndexer {
  return indexers[partitionForWord(word)];
}

proc enqueueIndexRequest(indexRequest: IndexRequest) {
  debug("enqueuing ", indexRequest);
  var indexer = indexerForWord(indexRequest.word);
  // TODO: do we need to go onto the indexer locale for this?  or will it just automatically be on that locale?
  on indexer {
    indexer.writeEntry(indexRequest);
  }
}

proc main() {
  initPartitions();
  initIndexer();

  var t: Timer;
  t.start();

  var infile = open("words.txt", iomode.r);
  var reader = infile.reader();
  var word: string;
  var docId: DocId = 0;
  while (reader.readln(word)) {
    enqueueIndexRequest(new IndexRequest(word, docId));
    docId = (docId + 1) % 1000 + 1; // fake doc ids
  }

  t.stop();
  timing("partition fanout complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
