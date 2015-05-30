module Logging {
  
  config const log_level = 1;

  inline proc debug(args ...?k) {
    if (log_level >= 5) {
      write(here.id, "\t");
      writeln((...args));
    }
  }

  inline proc info(args ...?k) {
    if (log_level >= 1) {
      write(here.id, "\t");
      writeln((...args));
    }
  }

  inline proc timing(args ...?k) {
    if (log_level >= 2) {
      write(here.id, "\t");
      writeln((...args));
    }
  }

  inline proc error(args ...?k) {
    write(here.id, "\tERROR\t");
    writeln((...args));
  }
}
