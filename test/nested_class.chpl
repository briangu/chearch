/*
test/nested_class.chpl:22: error: unresolved type specifier 'LockFreeHash(uint(32)).TableEntry'
test/nested_class.chpl:13: note: candidates are: TableEntry(_mt: _MT, outer)
*/
module LockFreeHash {
  
  type KeyType = uint(32);

  class LockFreeHash {
    type ValueType = uint(32);
    var hashSize: uint(32) = 1024*1024;

    record TableEntry {
      var key: atomic KeyType;
      var value: atomic ValueType;

      // test/nested_class.chpl:18: error: constructor for class 'TableEntry' requires a generic argument called 'outer'
      proc TableEntry(outer: LockFreeHash) {
        key.write(0);
      }
    }

    var array: [0..hashSize-1] TableEntry;

    // removed methods
  }
}