use Common, Logging, Memory, LibEv, IO, Search, Partitions, Time;

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
		dumpPartition(partitionForWord("dog"));
	} else {
		writeln("<adding>");
	  indexWord(trimmedWord, 1);
		dumpPostingTableForWord(trimmedWord);
		writeln("</adding>");
	}
  send(fd, buffer, read, 0);
}

proc initIndex() {
	writeln("This program is running on ", numLocales, " locales");
	writeln("It began running on locale #", here.id);
	writeln();

  initPartitions();

  if (load_from_partitions) {
    initIndicesFromPartitionDisks();
  } else {
    initIndices();

    var t: Timer;
    t.start();

    var infile = open("words.txt", iomode.r);
    var reader = infile.reader();
    var word: string;
    var docId: DocId = 1;
    while (reader.readln(word)) {
      indexWord(word, docId);
      docId = (docId + 1) % 1000 + 1; // fake different docs
    }

  //  waitForIndexer();
    t.stop();
    timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
  }

  // engage in super slow but interesting test
  if (post_load_test) {
    var t: Timer;

    dumpPostingTableForWord("the");

    // TODO: build execution Tree w/ conj / disj. (operator) nodes
    // test basic boolean operators
    writeln("conjunction");
    t.start();
    var conj = conjunction(["the", "dog"]);
    t.stop();
    timing("conjunction complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    writeln(conj);

    writeln("disjunction");
    t.start();
    var disj = disjunction(["the", "dog"]);
    t.stop();
    timing("disjunction complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    writeln(disj);
  }
}

// SUPER SLOW
proc conjunction(words: [] string): domain(DocId) {
  writeln("finding conjunction of: ", words);
  var doms: domain(DocId);
  
  var t: Timer;

  for j in 1..words.size {
    var word = words[j];
    t.start();
    var localdoms: domain(DocId) = documentIdsForWord(word);
    t.stop();
    timing("doc Ids for ", word," complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

    if (j > 1) {
      t.start();
      doms = doms & localdoms;
      t.stop();
      timing("& complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");
    } else {
      doms = localdoms;
    }
  }

  return doms;
}

// SUPER SLOW
proc disjunction(words: [] string): domain(DocId) {
  writeln("finding disjunction of: ", words);
  var doms: domain(DocId);
  
  for j in 1..words.size {
    var word = words[j];
    var localdoms: domain(DocId) = documentIdsForWord(word);
    if (j > 1) {
      doms = doms | localdoms;
    } else {
      doms = localdoms;
    }
  }

  return doms;
}

proc writeLocInfo(loc: locale) {
  on loc {
    writeln("locale #", here.id, "...");
    writeln("  ...is named: ", here.name);
    writeln("  ...has ", here.numCores, " processor cores");
    writeln("  ...has ", here.physicalMemory(unit=MemUnits.GB, retType=real), " GB of memory");
    writeln("  ...has ", here.maxTaskPar, " maximum parallelism");
  }
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
  initIndex();

	// writeln("initializing event loop...");

 //  // port c_accept_cb, c_read_cb
	// var w_accept: ev_io = new ev_io();
	// ev_io_init(w_accept, c_accept_cb, sd, EV_READ);
	// ev_io_start(EV_DEFAULT, w_accept);

	// while (1) {
	// 	ev_loop_fn(EV_DEFAULT, 0);
	// }
}
