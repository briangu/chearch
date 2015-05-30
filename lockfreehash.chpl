module LockFreeHash {
  
  use Logging, GenHashKey32;

  // Lock Free Hash depends on a uint(32) key type.  To change this will requiring switching out the genHashKey algos (supply a class?)
  type KeyType = string;
  type ValueType = uint(32);

  record TableEntry {
    var hashKey: atomic uint(32);
    var key: KeyType; // not thread safe
    var value: atomic ValueType;

    proc TableEntry(outer: LockFreeHash) {
      hashKey.write(0);
      key = nil;
    }
  }

  class LockFreeHash {
    // type ValueType = uint(32);
    var hashSize: uint(32) = 1024*1024; // must be power of 2

    // record TableEntry {
    //   var key: atomic KeyType;
    //   var value: atomic ValueType;

    //   proc TableEntry(outer: LockFreeHash) {
    //     key.write(0);
    //   }
    // }

    var array: [0..hashSize-1] TableEntry;

    proc setItem(key: KeyType, value: ValueType): bool {
      var hashKey: uint(32) = genHashKey32(key);
      var idx: uint(32) = hashKey;
      var count = 0;
      
      debug("key: ", key, " value: ", value);
      debug("count: ", count);

      while (count < array.size) {
        idx &= hashSize - 1;

        debug("idx: ", idx);

        var probedKey = array[idx].hashKey.read();
        debug("probedKey: ", probedKey);
        if (probedKey != hashKey || array[idx].key != key) {
          // The entry was either free, or contains another key.
          if (probedKey != 0) {
            idx += 1;
            count += 1;
            continue; // Usually, it contains another key. Keep probing.
          }

          // The entry was free. Now let's try to take it using a CAS.
          var stored = array[idx].hashKey.compareExchange(0, hashKey);
          debug("stored: ", stored);
          if (!stored) {
            idx += 1;
            count += 1;
            continue;       // Another thread just stole it from underneath us.
          }

          // Either we just added the key, or another thread did.

          array[idx].key = key;
        }

        // Store the value in this array entry.
        array[idx].value.write(value);
        return true;
      }

      if (count == array.size) {
        // out of capacity
        error("hash out of capacity");
      }

      return false;
    }

    proc getItem(key: KeyType): ValueType {
      var count = 0;

      debug("key: ", key);
      debug("count: ", count);

      var hashKey: uint(32) = genHashKey32(key);
      var idx: uint(32) = hashKey;

      while (count < array.size) {
        idx &= hashSize - 1;

        var probedKey = array[idx].hashKey.read();
        if (probedKey == hashKey && array[idx].key == key) {
          debug("found match for hashKey");
          return array[idx].value.read();
        }
        if (probedKey == 0) {
          return 0;
        }

        idx += 1;
        count += 1;

        debug("probedKey: ", probedKey, " count: ", count);
      }

      debug("exhuastive search and key not found");

      return 0;
    }
  }
}