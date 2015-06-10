/**
  This indexer is designed to provide synthetic data that can be used to do testing or profiling.
*/
module SyntheticDataIndexer {

  use Logging, Random, SearchIndex, Time;
  
  config const batchDocumentCount = 1024 * 1024; // FAKE document count for testing
  config const maxTermsPerDocument = 10;
  config const maxTermsIds = 16384; // max number of terms across all docs

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
      local {
        var seed = (17 * here.id * 2) + 1;
        var randStreamSeeded: RandomStream = new RandomStream(seed);

        for externalDocId in 1..batchDocumentCount {
          var docSize = (randStreamSeeded.getNext() * maxTermsPerDocument): uint + 1;
          var terms: [0..docSize-1] IndexTerm;
          var textLocation: uint(8) = 0;
          for termId in terms.domain {
            terms[termId].term = (randStreamSeeded.getNext() * maxTermsIds): Term;
            terms[termId].textLocation = textLocation;
            textLocation += 1;
          }
          addDocument(terms, externalDocId: uint);
        }

        // create a range of documents and terms that only exist on a single locale
        // using this fact, we can create precise remote lookup tests 
        var baseExternalId = batchDocumentCount + 1;
        var baseLocaleKnownTermId = ((here.id * 2048) + 1024 * 1024) : Term;

        for termIdStep in 1..1024 {
          for externalDocId in baseExternalId..#termIdStep {
            var terms: [0..0] IndexTerm;
            var textLocation: uint(8) = 0;
            for termId in terms.domain {
              terms[termId].term = (baseLocaleKnownTermId + (termIdStep - 1)): Term;
              terms[termId].textLocation = textLocation;
              textLocation += 1;
            }
            addDocument(terms, externalDocId: uint);
          }
          baseExternalId += termIdStep;
        }
      }

      release$ = true;
    }
  }

  const SyntheticDataSpace = {0..Locales.size-1};
  const SyntheticDataReplicatedSpace = SyntheticDataSpace dmapped ReplicatedDist();
  var batchIndexers: [SyntheticDataReplicatedSpace] BatchIndexer;

  proc startBatchIndexers() {
    var t: Timer;
    t.start();

    forall loc in Locales {
      on loc {
        local { // TODO: local probably not needed here
          var worker = new BatchIndexer();
          worker.worker();
          delete worker;
        }
      }
    }
    
    t.stop();
    timing("started batch indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc waitForBatchIndexers() {
    var t: Timer;
    t.start();

    // for loc in Locales {
    //   on loc {
    //     batchIndexers[here.id].waitForIndexer();
    //     delete batchIndexers[here.id];
    //     batchIndexers[here.id] = nil;
    //   }
    // }
    
    t.stop();
    timing("stopped batch indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }
}