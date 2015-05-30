use GenHashKey32;

type DocId = int(64);

proc main() {
  var intersection = conjunction(["the", "dog"]);
  writeln(intersection);
}

proc conjunction(words: [] string): domain(DocId) {
  writeln("finding conjunction of: ", words);
  var doms: [1..words.size] domain(DocId);
  
  for j in 1..words.size {
    var word = words[j];
    for docId in documentIdsForWord(word) {
      doms[j] += docId;
    }
  }

  writeln("applying intersection");

  for j in 2..words.size {
    doms[1] &= doms[j];
    // doms[1] = doms[1] & doms[j];
  }

  return doms[1];
}


proc documentIdsForWord(word: string) {
  var idx = genHashKey32(word) % 2;
  if (idx == 0) {
    return [1,2,3,4,5];
  } else if (idx == 1) {
    return [2,4,6,8,10];
  } else {
    return [1,2,5,6,7];
  }
}