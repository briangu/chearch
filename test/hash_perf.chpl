use Random, Time;

type Word = uint(32); // ARMv7 has a wordsize of 32-bit

inline proc genHashKey(h: Word): Word {
  const hashConst1: Word = 0x85ebca6b;
  const hashConst2: Word = 0xc2b2ae35;

  var k: Word = h;
  k ^= k >> 16;
  k *= hashConst1;
  k ^= k >> 13;
  k *= hashConst2;
  k ^= k >> 16;
  return k;
}


proc exercise(arr: [?D] Word, iterations: int, seed: int){

  var randStreamSeeded: RandomStream = new RandomStream(seed);

  var t: Timer;
  t.start();

  for i in [1..iterations] {
    var nextRand: Word = randStreamSeeded.getNext(): Word;
    var hash = genHashKey(nextRand) % D.size + D.low;
    arr[hash] += 1;
  }

  t.stop();
  writeln("completed in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}

var x = 4096;

for i in {1..16} {
  x *= 2;
  var arr: [0..x-1] Word;
  writeln("x = ", x);
  for z in {1..4} {
    exercise(arr, 1024*1024 * 16, 17);  
  }
}

