use LockFreeHash;

proc storeItemTest(lfh: LockFreeHash, key: KeyType, value: ValueType) {
  var success: bool;
  writeln("attempting to store value: ", value, " with key ", key);
  success = lfh.setItem(key, value);
  writeln("success = ", success);
  writeln("attempting to get value with key ", key);
  var fetchedValue: ValueType;
  fetchedValue = lfh.getItem(key);
  writeln("value == fetchedValue\t", value == fetchedValue);
}

proc basicSetGet() {
  var lfh = new LockFreeHash(2);
  var item1: ValueType = 32;
  var item2: ValueType = 48;
  var item3: ValueType = 64;
  writeln("\tcase1");
  storeItemTest(lfh, genHashKey32("hello1"), item1);
  writeln("\tcase2");
  storeItemTest(lfh, genHashKey32("hello2"), item2);
  writeln("\tcase3");
  storeItemTest(lfh, genHashKey32("hello3"), item3);
  delete lfh;
}

proc basicParallel() {
  var lfh = new LockFreeHash();
  writeln("\tcase1");
  var d: uint(32) = 1024;
  coforall i in 1..d {
    storeItemTest(lfh, i, i);
  }
  writeln("\tcase2");
  coforall i in 1..d {
    var fetchedValue = lfh.getItem(i);
    if (!fetchedValue) {
      // writeln("success = ", success);
      writeln("failed key: ", i, " value: ", i, " fetchedValue: ", fetchedValue);
    }
  }
  delete lfh;
}

proc main() {
  writeln("-------- basicSetGet");
  basicSetGet();
  writeln("-------- basicParallel");
  basicParallel();
}
