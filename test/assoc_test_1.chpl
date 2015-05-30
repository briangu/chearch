
use Random;

var Indices: domain(real);
var Entries: [Indices] real;

proc writeEntryForIndex(idx: real) {
  writeln("key: ", idx, " value: ", Entries[idx]);
}

proc dumpEntries() {
  writeln('dumping entries');
  for idx in Indices.sorted() {
    writeEntryForIndex(idx);
  }
  writeln();
}

Entries[0] = 2.71828;
dumpEntries();

Entries[1] = 3.141592;
dumpEntries();

var keysPerTask = 10;
var expectedSize = here.maxTaskPar * keysPerTask + Entries.size;

coforall i in 1..here.maxTaskPar {
  var randStream: RandomStream = new RandomStream();
  for j in 1..keysPerTask {
    var key = randStream.getNext();
    var value = randStream.getNext();
    writeln("task #", j, " adding key: ", key, " value: ", value);
    Entries[key] = value;
  }
}

var actualSize = Entries.size;
writeln("expectedSize: ", expectedSize, " actualSize: ", actualSize);
dumpEntries();

