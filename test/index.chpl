var count: atomic int; // used for this demo to release properly
var release$: single bool;

var indexing$: sync bool = false;
var arr: [1..1000] int;

count.write(1);
var i: int = 1; // can be any arbitraty value to assign into the array

while(i <= arr.size) {
  begin {
    var indexing = indexing$;

    arr[i] = i; // do some work on the arr

    count.add(1);
    if (count.read() == arr.size) {
      release$ = true;
    }

    indexing$ = false;
  }
  i += 1;
}

writeln("waiting...");

release$;

writeln("arr:");
writeln(arr);


