// #count doesn't preserve type of count

class Foo {
  var count: uint;
  var buffer: [0..#count] int;
}

var foo = new Foo(3);

// false
writeln(foo.count.type == foo.buffer.domain.high.type);

for i in 0..foo.count-1 {
  // count_type.chpl:22: error: unresolved access of '[domain(1,int(64),false)] int(64)' by '[uint(64)]'
  // writeln(foo.buffer[i]);
}

class Bar {
  var count: uint;
  var buffer: [0..count-1] int;
}

var bar = new Bar(3);

// true
writeln(bar.count.type == bar.buffer.domain.high.type);
for i in 0..bar.count-1 {
  writeln(bar.buffer[i]);
}
