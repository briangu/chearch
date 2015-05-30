module QueuedIndexer {

  use Logging, SearchIndex, Time;
  
  config const IndexerBufferSize = 1024;

  class IndexRequest {
    var D: domain;
    var terms: D IndexTerm;
    var externalDocId: ExternalDocId;
  }

  class QueuedIndexer {
    var bufferSize: int;
    var buff$: [0..buffersize-1] sync IndexRequest;
    var bufferIndex: atomic int;
    var release$: single bool;
    var t: Timer;

    proc QueuedIndexer() {
      // via nextBufferIndex, this is incremented to zero before first use
      bufferIndex.write(-1);
    }

    proc startConsumer() {
      begin {
        consumer();
      }
    }

    proc nextBufferIndex(): int {
      var idx: int;
      var success = false;
      while (!success) { 
        var originalValue = bufferIndex.read();
        idx = (originalValue + 1) % buffersize;
        success = bufferIndex.compareExchange(originalValue, idx);
      }
      return idx;
    }

    proc enqueueIndexRequest(terms: [?D] IndexTerm, externalDocId: uint) {
      var indexRequest = new IndexRequest(terms.domain, terms, externalDocId);
      const idx = nextBufferIndex();
      buff$(idx).writeEF(indexRequest);
      debug("enqueuing ", indexRequest);
    }

    proc waitForIndexer() {
      debug("waiting...");
      release$;
      debug("done waiting...");
    }

    proc markCompleteForIndexer() {
      debug("marking for completion");
      const idx = nextBufferIndex();
      buff$(idx).writeEF(nil);
      debug("halting consumer");
    }

    proc consumer() {
      for indexRequest in readFromBuff() {
        addDocument(indexRequest.terms, indexRequest.externalDocId);
      }
    }

    iter readFromBuff() {
      var ind = 0;
      var nextVal = buff$(ind);

      while (nextVal != nil) {
        yield nextVal;

        ind = (ind + 1) % buffersize;
        nextVal = buff$(ind);
      }

      release$ = true;
    }
  }

  const Space = {0..Locales.size-1};
  const ReplicatedSpace = Space dmapped ReplicatedDist();
  var queuedIndexers: [ReplicatedSpace] QueuedIndexer;

  proc startQueuedIndexers() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        local {
          queuedIndexers[i] = new Indexer();
        }
        queuedIndexers[i].startConsumer();
      }
    }

    t.stop();
    timing("started queued indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc stopQueuedIndexers() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        queuedIndexers[here.id].markCompleteForIndexer();
        queuedIndexers[here.id].waitForIndexer();
      }
    }
    
    t.stop();
    timing("stopped queued indexers in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }
}