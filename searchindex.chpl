module SearchIndex {

  use Logging, MemorySegment, ReplicatedDist, Search, Time;

  class PartitionManager {
    var segment: Segment;

    proc addDocument(terms: [?D] IndexTerm, externalDocId: ExternalDocId): bool {
      // TODO: handle multiple segments
      var success = segment.addDocument(terms, externalDocId);
      if (!success) {
        // TODO: handle segmentFull scenario
      }
      return success;
    }

    iter query(query: Query): QueryResult {
      // TODO: handle multiple segments
      for opValue in segment.query(query) {
        yield opValue;
      }
    }
  }

  // Map one partition to each locale
  const Space = {0..Locales.size-1};
  const ReplicatedSpace = Space dmapped ReplicatedDist();
  var Partitions: [ReplicatedSpace] PartitionManager;

  proc initPartitions() {
    var t: Timer;
    t.start();

    for loc in Locales {
      on loc {
        local {
          // TODO: handle multiple segments
          Partitions[here.id] = new PartitionManager(new MemorySegment());

          // ADD DUMMY to fill term 0
          var dummy: [0..0] IndexTerm;
          dummy[0].term = 0xFFFFFFFF;
          dummy[0].textLocation = 0;
          Partitions[here.id].addDocument(dummy, 1);

          NullOperand[here.id] = new Operand();
        }
      }
    }

    t.stop();
    timing("initialized partitions in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  proc addDocument(terms: [?D] IndexTerm, externalDocId: uint) {
    // Move to the locale the terms are on because the rest of this call will be local.
    // The caller must have already determined which partition the document should be on and allocated terms on that locale.
    on terms {
      // locally operate in the locale, which has one or more partitions.
      local {
        Partitions[here.id].addDocument(terms, externalDocId);
      }
    }
  }

  /**
    Query the local partition.  This is partly for test, as it may (likely) give partial index 
    results unless you know that your documents exist on the current locale.  
    NOTE: the caller could have already move execution to a locale of interest and then called this.
  */
  iter localQuery(query: Query) {
    local {
      for res in Partitions[here.id].query(query) {
        yield res;
      }
    }
  }

  // serial iterator
  iter query(query: Query) {

    var totalCounts = 0;
    var outerResults: [0..(Locales.size * 2048)-1] QueryResult; // max results 2048 per locale
    
    for loc in Locales {
      on loc {
        var innerResults: [0..2047] QueryResult;
        var innerCount = 0;

        // copy query into locale
        var lq: Query = new Query(query);

        local {
          for res in localQuery(lq) {
            innerResults[innerCount] = res;
            innerCount += 1;
            if (innerCount > innerResults.domain.high) {
              break;
            }
          }
        }

        if (innerCount > 0) {
          outerResults[totalCounts..totalCounts+innerCount-1] = innerResults[0..innerCount-1];
          totalCounts += innerCount;
        }
      }
    }

    for i in 0..totalCounts-1 {
      yield outerResults[i];
    }
  }

  iter query(param tag: iterKind, query: Query)
    where tag == iterKind.leader {
      coforall loc in Locales {
        on loc {
          // copy query into locale
          var lq: Query = new Query(query);

          var count = 0;
          local {
            for res in localQuery(lq) {
              yield res;
              count += 1;
              if (count > query.partitionLimit) {
                break;
              }
            }
          }
        }
    }
  }

  iter query(param tag: iterKind, query: Query, followThis)
    where tag == iterKind.follower && followThis.size == 1 {
      for i in followThis(1) {
        yield i;
      }
  }

  iter query(param tag: iterKind, query: Query)
    where tag == iterKind.standalone {
      coforall loc in Locales {
        on loc {
          // copy query into locale
          var lq: Query = new Query(query);

          var count = 0;
          local {
            for res in localQuery(lq) {
              yield res;
              count += 1;
              if (count > query.partitionLimit) {
                break;
              }
            }
          }
        }
      }
  }
}
