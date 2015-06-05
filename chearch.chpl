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
    if (result.term != 2) {
      halt("term not 2 ", result);
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for 3");
  t.clear();
  t.start();

  buffer.clear();
  writer.write_push();
  writer.write_term(3);

  count = 0;
  for result in query(new Query(buffer)) {
    if (result.term != 3) {
      halt("term not 3 ", result);
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for 3 AND 2");
  t.clear();
  t.start();

  buffer.clear();
  writer.write_push();
  writer.write_term(3);
  writer.write_push();
  writer.write_term(2);
  writer.write_and();

  count = 0;
  for result in query(new Query(buffer)) {
    if ((result.term != 3) && (result.term != 2)) {
      halt("term not 3 or 2 ", result);
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for 3 OR 2");
  t.clear();
  t.start();

  buffer.clear();
  writer.write_push();
  writer.write_term(3);
  writer.write_push();
  writer.write_term(2);
  writer.write_or();

  count = 0;
  for result in query(new Query(buffer)) {
    if ((result.term != 3) && (result.term != 2)) {
      halt("term not 3 or 2 ", result);
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for missing term");
  t.clear();
  t.start();

  buffer.clear();
  writer.write_push();
  writer.write_term(20000);

  count = 0;
  for result in query(new Query(buffer)) {
    if (result.term != 20000) {
      halt("should never find anything! ", result);
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");

  delete buffer;
}
