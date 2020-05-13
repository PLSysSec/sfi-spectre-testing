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
    #filename = sys.argv[1]
    filenames = [filename for filename in sys.argv[1:]]
    print(filenames)
    #n = int(sys.argv[2])
    #benches = load_benches(filename)
    bencheset = [load_benches(filename) for filename in filenames]
    #n = compute_n(benches) 
    nset = [compute_n(benches) for benches in bencheset]
    #print("n = ", n)
    for idx in range(len(nset)):
        benches = bencheset[idx]
        n = nset[idx]
        fig = plt.figure(idx)
        make_graph(benches, n, fig, filenames[idx] + ".pdf", filenames[idx] + "_stats.txt")

def empty_vals(n):
  vals = []
  for jdx in range(n):
      vals.append([])
  return vals

def make_graph(benches, n, fig, outfile, statsfile):
    idx = 0
    labels = []
    implementations = []    
    vals = empty_vals(n)

    width = (1.0 / (n + 1))        # the width of the bars
    
    ax = fig.add_subplot(111)

    plt.rcParams['pdf.fonttype'] = 42 # true type font
    plt.rcParams['font.family'] = 'Times New Roman'
    plt.rcParams['font.size'] = '8'

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

    print(vals)

    rects = []
    for idx,val in enumerate(vals):
      rects.append(ax.bar(ind + width*idx, val, width))


    ax.set_xlabel('Sightglass Benchmarks')
    ax.set_ylabel('Relative Execution Time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    ax.set_xticklabels(labels)
    #print(rects, implementations)
    ax.legend( tuple(rects), implementations )
    fig.subplots_adjust(bottom=0.25)


    for i in range(n):
        result_average = sum(vals[i]) / N 
        result_median = median(vals[i])
        with open(statsfile, "a") as myfile:
          myfile.write(f"{implementations[i]} average = {result_average} {implementations[i]} median = {result_median}\n")

    plt.savefig(outfile, format="pdf")
    #plt.show()


if __name__== "__main__":
  main()

