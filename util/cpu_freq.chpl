use IO;

// tool to scan CPU frequency on Jetson TK1 (and generally linux OS)
config const cpu_freq_file = "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq";

for loc in Locales {
  on loc {
    var infile = open(cpu_freq_file, iomode.r);

    var line: string;
    for line in infile.lines() {
      write(here.name, " ", line);
    }
  }
}