// hash functions lifted from DefaultAssociative.chpl

// 64-bit
module GenHashKey64 {
  inline proc genHashKey(i: uint(64)): uint(64) {
    var key = i;
    key += ~(key << 32);
    key = key ^ (key >> 22);
    key += ~(key << 13);
    key = key ^ (key >> 8);
    key += (key << 3);
    key = key ^ (key >> 15);
    key += ~(key << 27);
    key = key ^ (key >> 31);
    return (key & max(uint(64))): uint(64);  // YAH, make non-negative
  }

  inline proc genHashKey(x: c_string): uint(64) {
    var hash: uint(64) = 0;
    for c in 1..(x.length) {
      hash = ((hash << 5) + hash) ^ ascii(x.substring(c));
    }
    return genHashKey(hash);
  }

  inline proc genHashKey(x: string): uint(64) {
    return genHashKey(x.c_str());
  }
}
