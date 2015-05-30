// hash functions lifted from DefaultAssociative.chpl

// 32-bit
module GenHashKey32 {

  // https://code.google.com/p/smhasher/wiki/MurmurHash3
  inline proc genHashKey32(h: uint(32)): uint(32) {
    const hashConst1: uint(32) = 0x85ebca6b;
    const hashConst2: uint(32) = 0xc2b2ae35;

    var k: uint(32) = h;
    k ^= k >> 16;
    k *= hashConst1;
    k ^= k >> 13;
    k *= hashConst2;
    k ^= k >> 16;
    return k;
  }

  inline proc genHashKey32(x: c_string): uint(32) {
    var hash: uint(32) = 0;
    for c in 1..(x.length) {
      hash = ((hash << 5) + hash) ^ ascii(x.substring(c));
    }
    return genHashKey32(hash);
  }

  inline proc genHashKey32(x: string): uint(32) {
    return genHashKey32(x.c_str());
  }
}
