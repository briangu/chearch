/**
  This indexer is designed to provide synthetic data that can be used to do testing or profiling.
*/
module SyntheticDataIndexer {

  use Logging, Random, SearchIndex, Time;
  
  config const batchDocumentCount = 1024 * 1024; // FAKE document count for testing
  config const maxTermsPerDocument = 10;
  config const maxTermsIds = 16384; // max number of terms across all docs

  class SyntheticDataIndexer {
    var t: Timer;

    proc work() {
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
    }
  }

  proc indexSyntheticDocuments() {
    var t: Timer;
    t.start();

    // TODO: once the overall CPU hog problem is understood,
    //       put back running these indexers as workers in begin blocks 
    //       add back: startIndexers, waitForIndexers
    forall loc in Locales {
      on loc {
        local {
          var worker = new SyntheticDataIndexer();
          worker.work();
          delete worker;
        }
      }
    }
    
    t.stop();
    timing("finished indexing in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }
}