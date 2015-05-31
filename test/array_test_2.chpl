

class Item {
  var s: string;
}

proc mkarr(ref items: [?D] Item) {
  D = {1..100};
  var a: [D] Item;
  items = a;
}

var d: domain(1);
var items: [d] Item;
mkarr(items);
writeln(items);

