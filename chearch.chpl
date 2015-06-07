use BatchIndexer, Logging, SearchIndex, Time;

/**
  This is server-less mode of Chearch that should eventually have a repl
*/
proc main() {

  // simple class to escape the const intents of forall
  class Counter {
    var count: uint;
  }

  writeln("using ", Locales.size, " locales");
  writeln("initializing index");
  initPartitions();

  // batch load the index from storage
  var t: Timer;
  t.start();

  startBatchIndexers();
  waitForBatchIndexers();

  t.stop();
  writeln("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

  var counts = new Counter();

  // this will hold the query instruction
  var buffer = new InstructionBuffer(32);

  // perform sample queries
  var writer = new InstructionWriter(buffer);

  writeln("---querying locally for 2");
  {
    counts.count = 0;

    buffer.clear();
    writer.write_push();
    writer.write_term(2);

    t.clear();
    t.start();
    for result in localQuery(new Query(buffer)) {
      if (result.term != 2) {
        halt("term not 2 ", result);
      }
      counts.count += 1;
    }
    t.stop();
    writeln("count = ", counts.count);
    writeln("local query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  writeln("---querying remotely for 2");
  {
    counts.count = 0;

    for loc in Locales {
      if (loc.id == here.id) {
        continue;
      }
      buffer.clear();
      writer.write_push();
      writer.write_term(2);

      t.clear();
      t.start();
      for result in localQuery(new Query(buffer)) {
        if (result.term != 2) {
          halt("term not 2 ", result);
        }
        counts.count += 1;
      }
      t.stop();
      writeln("count = ", counts.count);
      writeln("remote query on ",here.id," in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    }
  }

  writeln("---querying for 3");
  {
    counts.count = 0;

    buffer.clear();
    writer.write_push();
    writer.write_term(3);

    t.clear();
    t.start();
    forall result in query(new Query(buffer)) {
      if (result.term != 3) {
        halt("term not 3 ", result);
      }
      counts.count += 1;
    }
    t.stop();
    writeln("count = ", counts.count);
    writeln("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  writeln("---querying for 3 AND 2");
  {
    counts.count = 0;

    buffer.clear();
    writer.write_push();
    writer.write_term(3);
    writer.write_push();
    writer.write_term(2);
    writer.write_and();

    t.clear();
    t.start();
    forall result in query(new Query(buffer)) {
      if ((result.term != 3) && (result.term != 2)) {
        halt("term not 3 or 2 ", result);
      }
      counts.count += 1;
    }
    t.stop();
    writeln("count = ", counts.count);
    writeln("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  writeln("---querying for 3 OR 2");
  {
    counts.count = 0;

    buffer.clear();
    writer.write_push();
    writer.write_term(3);
    writer.write_push();
    writer.write_term(2);
    writer.write_or();

    t.clear();
    t.start();
    forall result in query(new Query(buffer)) {
      if ((result.term != 3) && (result.term != 2)) {
        halt("term not 3 or 2 ", result);
      }
      counts.count += 1;
    }
    t.stop();
    writeln("count = ", counts.count);
    writeln("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  writeln("---querying for missing term");
  {
    counts.count = 0;

    buffer.clear();
    writer.write_push();
    writer.write_term(1024*1024 * 8);

    t.clear();
    t.start();
    forall result in query(new Query(buffer)) {
      writeln(result);
      counts.count += 1;
    }
    t.stop();
    writeln("count = ", counts.count);
    if (counts.count > 0) {
      halt("counts > 0!");
    }
    writeln("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  delete buffer;
}
