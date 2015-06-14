proc foo(bar: [?D] int) {
  var baz: [?D] int;
  baz[0] = 1;
  writeln(baz);
}

var arr: [1..3] int;
foo(arr);
