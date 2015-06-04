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
  var count = 0;
  for result in localQuery(new Query(2)) {
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
  count = 0;
  for result in query(new Query(3)) {
    if (result.term != 3) {
      halt();
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
