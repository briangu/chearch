use Logging, Memory, IO, Partitions, Time;

class Node {
  var word: string;
  var next: Node;
}

class PartitionInfo {
  var head: Node;
  var count: atomic int;
}

class WordIndex {
  var wordIndex: [0..Partitions.size-1] PartitionInfo;

  proc WordIndex() {
    for i in wordIndex.domain {
      on Partitions[i] {
        writeln("adding ", i);
        wordIndex[i] = new PartitionInfo();
      }      
    }
  }

  proc indexWord(word: string) {
    var partition = partitionForWord(word);
    var info = wordIndex[partition];
    on info {
      info.head = new Node(word, info.head);
      info.count.add(1);
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
  while (reader.readln(word)) {
    wordIndex.indexWord(word);
  }

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}