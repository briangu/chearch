use Logging, Memory, LibEv, IO, Random, SearchIndex, SyntheticDataIndexer, Time;

// ****
// NOTE: this is very much in progress
// ****

// TODO: port to pure chapel
extern proc initialize_socket(port: c_int): c_int;

// trampolines
extern var c_accept_cb: opaque;

extern proc send(sockfd:c_int, buffer: c_string, len: size_t, flags: c_int);

config const port: c_int = 3033;
config const post_load_test: bool = false;
config const load_from_partitions: bool = true;

// TODO: is the fd unique enough to bind a multi-handle processing context to?
export proc handle_received_data(fd: c_int, tcp_buffer: c_string, read: size_t, buffer_size: size_t) {
  // simulate processing the query
  var buffer = new InstructionBuffer(32);
  var writer = new InstructionWriter(buffer);
  buffer.clear();
  writer.write_push();
  writer.write_term(2);

  forall result in query(new Query(buffer)) {
    writeln(result);
  }

  send(fd, tcp_buffer, read, 0);
}

proc main() {

  info("initializing index");
  initPartitions();

  // POPULATE THE INDEX

  var t: Timer;
  t.start();

  startBatchIndexers();
  waitForBatchIndexers();

  t.stop();
  timing("indexing complete in ",t.elapsed(TimeUnits.microseconds), " microseconds");

  info("initializing event loop...");

  info("creating socket...");
  var sd: ev_fd = initialize_socket(port);
  debug("socket id = ", sd);
  if (sd == -1) {
    error("socket error");
    return -1;
  }

  // port c_accept_cb, c_read_cb
  var w_accept = new ev_io();
  ev_io_init(w_accept, c_accept_cb, sd, EV_READ);
  ev_io_start(EV_DEFAULT, w_accept);

  while (1) {
    ev_loop_fn(EV_DEFAULT, 0);
  }

  return 0;
}
