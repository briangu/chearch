module BatchIndexer {

  use Logging, SearchIndex, Time;
  
  class BatchIndexer {
    var release$: single bool;
    var t: Timer;

    proc startWorker() {
      begin {
        worker();
      }
    }

    proc waitForIndexer() {
      debug("waiting...");
      release$;
      debug("done waiting...");
    }

    proc worker() {
      var infile = open("data/words.txt", iomode.r);

      local {
        var term: string;
        var externalDocId: uint = 0;
        var count: uint(32) = 0;
        var termCount: uint(32) = 1;
        var textLocation: uint(8) = 0;

        // var seed = 17;
        // var randStreamSeeded: RandomStream = new RandomStream(seed);
        // var docSize = randStreamSeeded.getNext(): int % 1000;
        var docSize = 100;
        var terms: [0..docSize-1] IndexTerm;

        for term in infile.lines() {
          if (count < docSize) {
            terms[count].term = termCount + 1;
            terms[count].textLocation = textLocation;
            count += 1;
            textLocation += 1;
          } else {
            addDocument(terms, externalDocId);

            // docSize = randStreamSeeded.getNext(): int % 1000;
            // terms.domain = {1..docSize};
            count = 0;
            externalDocId += 1;
          }
          termCount = termCount % 10000;
          termCount += 1;
        }

        // if (count > 0) {
        //   var subTerms = terms[0..count-1];
        //   addDocument(subTerms, externalDocId);
        // }
      }

      release$ = true;
    }
  }

  const Space = {0..Locales.size-1};
  const ReplicatedSpace = Space dmapped ReplicatedDist();
  var batchIndexers: [ReplicatedSpace] BatchIndexer;

  proc startBatchIndexers() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        local {
          batchIndexers[here.id] = new BatchIndexer();
        }
        batchIndexers[here.id].startWorker();
      }
    }
    
    t.stop();
    timing("started batch indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc waitForBatchIndexers() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        batchIndexers[here.id].waitForIndexer();
      }
    }
    
    t.stop();
    timing("stopped batch indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }
}