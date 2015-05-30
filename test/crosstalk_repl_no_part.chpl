use GenHashKey32, Logging, Memory, IO, ReplicatedDist, Time;

class Node {
  var word: string;
  var next: Node;
}

class PartitionInfo {
  var head: Node;
  var count: atomic int;
}

// Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
const ReplicatedSpace = domain(1) dmapped ReplicatedDist();
var Partitions: [ReplicatedSpace] PartitionInfo;

proc initPartitions() {
  var t: Timer;
  t.start();

  writeln("Partitions");
  writeln(Space);
  writeln(ReplicatedSpace);
  writeln(Partitions);
  writeln();

  var tmpPartitions: [Space] PartitionInfo;
  for i in tmpPartitions.domain {
    tmpPartitions[i] = new PartitionInfo();
  }

  // assign to the replicated Partitions array, causing a global replication of the array
  Partitions = tmpPartitions;

  writeln("Partitions");
  writeln(Partitions);
  writeln();

  t.stop();
  timing("initialized partitions in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}

inline proc localeForWord(word: string): locale {
  return Locales[genHashKey32(word) % Locales.size];
}

proc indexWord(word: string) {
  // first move the locale that should have the word.  There may be more than one active partition on a single locale.
  on localeForWord(word) {
    // locally operate on the partition info that the word maps to
    var info = partitionInfoForWord(word); // TODO: this should be already local w/o the local keyword
    local {
      info.head = new Node(word, info.head);
      info.count.add(1);
    }
  }
}

proc main() {
  initPartitions();

  var t: Timer;
  t.start();

  var infile = open("words.txt", iomode.r);
  var reader = infile.reader();
  var word: string;

  // TODO: parallelize reads
  while (reader.readln(word)) {
    indexWord(word);
  }

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}

