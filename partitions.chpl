module Partitions {

  use Logging, GenHashKey32, Sort, Time;
  
  // Number of dimensions in the partition space.
  // Each partition will be projected to a locale.  
  // If the number of partitions exceeds the number of locales, 
  // then the locales will be over-subscribed with possibly more than one
  // partition per locale.
  config var partitionDimensions = 16; //Locales.size;

  // Partition to locale mapping.  Zero-based to allow modulo to work conveniently.
  var Partitions: [0..partitionDimensions-1] locale;

  // TODO: need to sort partitions by id so they always come up the same order

  // project the partitions down to the locales
  proc initPartitions() {
    var t: Timer;
    t.start();

    // this code ensures that given a set of hosts, they are consistently ordered between boots in the same partition order.
    var hostDomain: domain(string);
    var hostMap: [hostDomain] locale;
    for loc in Locales {
      hostMap[loc.name] = loc;
    }
    var hostnames = hostDomain.sorted();
    writeln(hostnames);

    for i in Partitions.domain {
      var hostname = hostnames[i % hostnames.size + 1];
      Partitions[i] = hostMap[hostname];
      on Partitions[i] {
        info("partition[", i, "] is mapped to locale ", here.id, ' on ', Partitions[i].name);
      }
    }

    t.stop();
    timing("initialized partitions in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  /**
    Map a word to a partition.
  */
  proc partitionForWord(word: string): int {
    return genHashKey32(word) % Partitions.size;
  }
}