use IO;

const config cpu_freq_file = /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"

for loc in Locales {
  on loc {
    var infile = open("data/words.txt", iomode.r);

    var line: string;
    for line in infile.lines() {
      writeln(here.hostname, " ", line);
    }
  }
}
