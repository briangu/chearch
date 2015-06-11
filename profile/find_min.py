import sys

m = None

for line in sys.stdin:
  if m == None:
    m = [float(v) for v in line.strip().split(",")]
  i = 0
  for r in line.strip().split(","):
    v = float(r)
    if v < m[i]:
      m[i] = v
    i += 1

print sys.argv[1] + "," + ",".join(map(str, m))

