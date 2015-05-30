

var idx$: [1..10] sync int;

proc readValue(id: string) {
  for j in 1..10 {
    writeln(id, " waiting for ", j);
    var i = idx$(j);
    writeln(id, ": idx(",j,") got ", i);
  }
}

writeln("kicking off readers");

begin {
  readValue("a");
}

begin {
  readValue("b");
}

begin {
  readValue("c");
}

writeln("assigning values...");

for k in 1..10 {
  idx$(k) = k;
}
