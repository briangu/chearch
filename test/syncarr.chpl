var count$: sync int = 0;
var release$: single bool;
var arr: [1..1000] int;
var i: int = 1; // can be any arbitraty value to assign into the array

while(i <= arr.size) {
  begin {
    var count = count$;
    arr[i] = i;
    count$ = count + 1;
    if (count + 1 == arr.size) {
      release$ = true;
    }
  }
  i += 1;
}

writeln("waiting...");

release$;

writeln("arr:");
writeln(arr);


