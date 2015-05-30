use GenHashKey32, Logging, Memory, IO, ReplicatedDist, Time;

type WordType = uint(32);

class Node {
  var word: WordType;
  var next: Node;
}

class PartitionInfo {
  var head: Node;
  var count: atomic int;

  var writerLock: atomicflag;

  inline proc lockWriter() {
    while writerLock.testAndSet() do chpl_task_yield();
  }

  inline proc unlockWriter() {
    writerLock.clear();
  }
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
config const partitionDimensions = 16;

// Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
const Space = {0..partitionDimensions-1};
const ReplicatedSpace = Space dmapped ReplicatedDist();
var Partitions: [ReplicatedSpace] PartitionInfo;

proc initPartitions() {
  var t: Timer;
  t.start();

  debug("Partitions");
  debug(Space);
  debug(ReplicatedSpace);
  debug(Partitions.size);
  debug(Partitions);

  for loc in Locales {
    on loc {
      for i in Partitions.domain {
        Partitions[i] = new PartitionInfo();
      }
    }
  }

  debug("Partitions [after init]");
  debug(Partitions);

  t.stop();
  timing("initialized partitions in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}

inline proc partitionIdForWord(word: WordType): int {
  return genHashKey32(word) % partitionDimensions;
} 

inline proc localeForWord(word: WordType): locale {
  return Locales[partitionIdForWord(word) % Locales.size];
}

// should be a local lookup
inline proc partitionInfoForWord(word: WordType): PartitionInfo {
  return Partitions[partitionIdForWord(word)];
}

// override method to make it easy to switch WordType from string to uint(32)
inline proc genHashKey32(x: uint(32)): uint(32) {
  return x;
}

// override method to make it easy to switch WordType from string to uint(32)
inline proc indexWord(word: string) {
  indexWord(genHashKey32(word));
}

proc indexWord(word: WordType) {
  // first move the locale that should have the word.  There may be more than one active partition on a single locale.
  on localeForWord(word) {
    // locally operate on the partition info that the word maps to
    local {
      var info = partitionInfoForWord(word);
      var newNode = new Node(word); // do allocation outside of lock
      info.lockWriter();
      newNode.next = info.head;
      info.head = newNode;
      info.unlockWriter();
      info.count.add(1);
      debug(Partitions);
    }
  }
}

proc main() {
  initPartitions();

  var t: Timer;
  t.start();

  var infile = open("words.txt", iomode.r);

  coforall word in infile.lines() {
    indexWord(word);
  }

  debug(Partitions);

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
