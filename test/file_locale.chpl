use IO;

for loc in Locales {
  on loc {
    local {
      var count = 0;
      var infile = open("data.txt", iomode.r);
      var row: string;
      for row in infile.lines() {
        count += 1;
      }
      writeln("count = ", count);
    }
  }
}
