import numpy as np
import matplotlib.pyplot as plt
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

    width = (1.0 / (n + 1))        # the width of the bars
    fig = plt.figure()
    ax = fig.add_subplot(111)


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
    ind = np.arange(N)
    labels = tuple(labels)

    rects = []
    for idx,val in enumerate(vals):
      rects.append(ax.bar(ind + width*idx, val, width))


    ax.set_xlabel('Sightglass Benchmarks')
    ax.set_ylabel('Relative Execution Time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    ax.set_xticklabels(labels)
    print(rects, implementations)
    ax.legend( tuple(rects), implementations )
    fig.subplots_adjust(bottom=0.25)


    for i in range(n):
        result_average = sum(vals[i]) / N 
        result_median = median(vals[i])
        print(f"{implementations[i]} average = {result_average} {implementations[i]} median = {result_median}")

    plt.show()


if __name__== "__main__":
  main()


def plot3():
    benches = load_benches() 

    width = 0.27       # the width of the bars

    fig = plt.figure()
    ax = fig.add_subplot(111)

    idx = 0
    labels = []
    vals0 = []
    vals1 = []
    vals2 = []
    implementations = []

    benches = benches[1:-1]
    #print(len(benches), benches)
    for bench in benches:
      print(bench)

    for bench in benches:
      if not bench or bench[0] == "seqhash":
        continue
      if idx < 3:
        implementations.append(bench[1])
      ratio = float(bench[2])
      if idx % 3 == 0:
          labels.append(bench[0])
          vals0.append(ratio)
      
      elif idx % 3 == 1:
        vals1.append(ratio)
      
      elif idx % 3 == 2:
        vals2.append(ratio)
    
      idx += 1
    
    N = len(labels)
    ind = np.arange(N)
    labels = tuple(labels)


    rects1 = ax.bar(ind, vals0, width, color='r')
    rects2 = ax.bar(ind+width, vals1, width, color='g')
    rects3 = ax.bar(ind+width*2, vals2, width, color='b')

    #ax.set_ylabel('Ratio of Native')
    #ax.set_xticks(ind+width)

    ax.set_xlabel('Sightglass Benchmarks')
    ax.set_ylabel('Ratio of Lucet Performance')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    ax.set_xticklabels(labels)
    ax.legend( (rects1[0], rects2[0], rects3[0]), implementations )
    fig.subplots_adjust(bottom=0.25)

    lucet_average = sum(vals0) / N 
    lucet_median = median(vals0)
    print(f"lucet_average = {lucet_average} lucet_median = {lucet_median}")

    spectre_average = sum(vals1) / N 
    spectre_median = median(vals1)
    print(f"spectre_average = {spectre_average} spectre_median = {spectre_median}")

    fence_average = sum(vals2) / N 
    fence_median = median(vals2)
    print(f"fence_average = {fence_average} fence_median = {fence_median}")

   
    plt.show()

