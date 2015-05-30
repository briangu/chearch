
var lock$: sync int = 0;
var counter: int;

proc doWork() {
  var lock = lock$;
  writeln("incrementing: ", counter);
  counter += 1;
  lock$ = 0;
}

coforall 1..1024*64 {
  doWork();  
}
