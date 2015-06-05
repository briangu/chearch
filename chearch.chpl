use BatchIndexer, Logging, SearchIndex, Time;

/**
  This is server-less mode of Chearch that should eventually have a repl
*/
proc main() {

  writeln("initializing index");
  initPartitions();

  // batch load the index from storage
  var t: Timer;
  t.start();

  startBatchIndexers();
  waitForBatchIndexers();

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

  // perform sample queries
  writeln("querying for 2");
  t.clear();
  t.start();

  var buffer = new InstructionBuffer(1024);
  var writer = new InstructionWriter(buffer);
  writer.write_push();
  writer.write_term(2);

  var count = 0;
  for result in localQuery(new Query(buffer)) {
    // writeln(result);
    if (result.term != 2) {
      halt();
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for 3");
  t.clear();
  t.start();

  buffer.rewind();
  writer.write_push();
  writer.write_term(3);

  count = 0;
  for result in query(new Query(buffer)) {
    if (result.term != 3) {
      halt();
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
