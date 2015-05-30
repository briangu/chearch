use Logging, IO, Partitions;

proc main() {
  initPartitions();

  var t: Timer;
  t.start();

  for partition in Partitions {
    on partition {
      var infile = open("/tmp/words" + here.id + ".txt", iomode.cwr);
      var writer = infile.writer();
      writer.writeln("I'm here at ", here.id);
    }
  }

  t.stop();
  timing("complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
}
