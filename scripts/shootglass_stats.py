import numpy as np
import sys

def median(lst):
    n = len(lst)
    s = sorted(lst)
    return (sum(s[n//2-1:n//2+1])/2.0, s[n//2])[n % 2] if n else None

def load_benches(filename):
    with open(filename) as f:
        lines = f.read().split("\n")

    benches = [line.split() for line in lines]
    return benches[1:-1]

def compute_n(benches):
  implementations = set()
  n = 0
  for bench in benches:
      if not bench or bench[0] == "seqhash":
        continue
      if bench[1] not in implementations:
        implementations.add(bench[1])
        n += 1
  return n

def main():
    filename = sys.argv[1]
    #n = int(sys.argv[2])
    benches = load_benches(filename)
    n = compute_n(benches) 
    #print("n = ", n)
    compute_stats(benches, n)

def empty_vals(n):
  vals = []
  for jdx in range(n):
      vals.append([])
  return vals

def compute_stats(benches, n):
    idx = 0
    labels = []
    implementations = []    
    vals = empty_vals(n)

    for bench in benches:
      if not bench or bench[0] == "seqhash":
        continue
      if idx < n:
        implementations.append(bench[1])

      ratio = float(bench[2])
      if idx % n == 0:
          labels.append(bench[0])

      for edx in range(n):
          if idx % n == edx:
              vals[edx].append(ratio)
    
      idx += 1
    
    N = len(labels)

    for i in range(n):
        result_average = sum(vals[i]) / N 
        result_median = median(vals[i])
        print(f"{implementations[i]} average = {result_average} {implementations[i]} median = {result_median}")


if __name__== "__main__":
  main()

