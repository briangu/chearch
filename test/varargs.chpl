use Logging;

// proc info(args...?k) {
//   writeln((...args));
// }

proc main() {
  info("hello ", 1, " this is ", 2);

  for i in 0..numLocales-1 {
    on Locales[i] {
      info("index [", i, "] is mapped to partition ", here.id);
    }
  }
}
