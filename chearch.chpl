use Logging, SearchIndex, SyntheticDataIndexer, Time;

config const peformAR = true;

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

  indexSyntheticDocuments();

  var t: Timer;

  writeln("---querying 2 on each locale");
  {
    for loc in Locales {
      on loc {
        var counts = new Counter();
        var t: Timer;
        local {
          var buffer = new InstructionBuffer(32);
          var writer = new InstructionWriter(buffer);
          buffer.clear();
          writer.write_push();
          writer.write_term(2);

          t.start();
          for result in localQuery(new Query(buffer)) {
            if (result.term != 2) {
              halt("term not 2 ", result);
            }
            counts.count += 1;
          }
          t.stop();

          delete buffer;
        }
        writeln("AL-", here.id, ",", Locales.size, ", ", t.elapsed(TimeUnits.microseconds), ",", counts.count);
      }
    }
  }

  var counts = new Counter();

  // this will hold the query instruction
  var buffer = new InstructionBuffer(32);

  // perform sample queries
  var writer = new InstructionWriter(buffer);

  if (peformAR) {
    writeln("---querying 2 on remote locales");
    for loc in Locales {
      if (loc.id == here.id) {
        continue;
      }

      var baselocaleKnownTermId = ((loc.id * 2048) + 1024 * 1024) : Term;
      var queryTimes: [1..1024] real; 

      for termIdStep in queryTimes.domain {
        counts.count = 0;

        var localeKnownTermId = (baselocaleKnownTermId + termIdStep - 1): Term;

        buffer.clear();
        writer.write_push_term(localeKnownTermId);

        t.clear();
        t.start();
        for result in query(new Query(buffer)) {
          if (result.term != localeKnownTermId) {
            halt("term not ", localeKnownTermId, " got ", result);
          }
          counts.count += 1;
        }
        t.stop();
        queryTimes[termIdStep] = t.elapsed(TimeUnits.microseconds);
      }
      writeln("AR-", here.id, ",", Locales.size, ", ", queryTimes);
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
    writeln("B,", Locales.size, ", ", t.elapsed(TimeUnits.microseconds), ",", counts.count);
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
    writeln("C,", Locales.size, ", ", t.elapsed(TimeUnits.microseconds), ",", counts.count);
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
    writeln("D,", Locales.size, ", ", t.elapsed(TimeUnits.microseconds), ",", counts.count);
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
    if (counts.count > 0) {
      halt("counts > 0!");
    }
    writeln("E,", Locales.size, ", ", t.elapsed(TimeUnits.microseconds), ",", counts.count);
  }

  delete buffer;
}
