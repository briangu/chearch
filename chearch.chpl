use BatchIndexer, Logging, Memory, LibEv, IO, Random, SearchIndex, Time;

// TODO: port to pure chapel
extern proc initialize_socket(port: c_int): c_int;

// trampolines
extern var c_accept_cb: opaque;

extern proc send(sockfd:c_int, buffer: c_string, len: size_t, flags: c_int);

config const port: c_int = 3033;
config const post_load_test: bool = false;
config const load_from_partitions: bool = true;

// TODO: we need to know which client context this is so that we can maintain parsing context
//       is the fd enough?
export proc handle_received_data(fd: c_int, buffer: c_string, read: size_t, buffer_size: size_t) {
  // writeln("from chpl: " + buffer);
  // accumulate string buffer
  var word = buffer;
  var trimmedWord: string = "";
  writeln("word: ", word);
  for i in 1..word.length {
  	var ch = word.substring(i);
  	if (ch != "\r" && ch != "\n") {
	  	writeln("ch: ", word.substring(i));
	  	trimmedWord += word.substring(i);
  	}
  }
//  writeln("trimmedWord: ", trimmedWord);
	if (trimmedWord == "dump") {
		// dumpPartition(partitionForWord("dog"));
	} else {
		writeln("<adding>");
	 //  indexWord(trimmedWord, 1);
		// dumpPostingTableForWord(trimmedWord);
		writeln("</adding>");
	}
  send(fd, buffer, read, 0);
}

proc main() {

	// writeln("creating socket...");
	// var sd: ev_fd = initialize_socket(port);
	// writeln("socket id = ", sd);
	// if (sd == -1) {
	// 	writeln("socket error");
	// 	return -1;
	// }

  writeln("initializing index");
  initPartitions();

  // POPULATE THE INDEX

  var t: Timer;
  t.start();

  startBatchIndexers();
  waitForBatchIndexers();

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

  // PERFORM QUERIES

  writeln("querying for 2");
  t.clear();
  t.start();
  var count = 0;
  for result in localQuery(new Query(2)) {
    // writeln(result);
    if (result.term != 2) {
      halt();
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");


  writeln("querying for 3");
  t.clear();
  t.start();
  count = 0;
  for result in query(new Query(3)) {
    if (result.term != 3) {
      halt();
    }
    count += 1;
  }
  writeln("count = ", count);
  t.stop();
  timing("query in ",t.elapsed(TimeUnits.microseconds), " microseconds");

	// writeln("initializing event loop...");

 //  // port c_accept_cb, c_read_cb
	// var w_accept: ev_io = new ev_io();
	// ev_io_init(w_accept, c_accept_cb, sd, EV_READ);
	// ev_io_start(EV_DEFAULT, w_accept);

	// while (1) {
	// 	ev_loop_fn(EV_DEFAULT, 0);
	// }
}
