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
    benches = [line.split() for line in lines if line][1:]
    return benches

'''
Count the number of implementations
'''
def compute_n(benches):
  implementations = set()
  n = 0
  for bench in benches:
      #if not bench or bench[0] == "seqhash":
      #  continue
      if bench[1] not in implementations:
        implementations.add(bench[1])
        n += 1
  return n

def get_all_benches(bencheset):
    all_benches = []
    #flatten into 1 list
    # processed_benches = [(bench,implementation,mean)]
    for benches in bencheset:
        processed_benches = [bench[:2] + bench[-1:] for bench in benches]
        all_benches.extend(processed_benches)

    # Get raw execution times for reference implementation
    ref_performance = {}
    for bench in all_benches:
      if bench[1] == "1.Reference":
        ref_performance[bench[0]] = float(bench[2]) 

    #Normalize benchmarks
    final_benches = []
    for bench in all_benches:
      name = bench[0]
      t = float(bench[-1]) / ref_performance[name]
      final_benches.append(bench[:2] + [t])

    final_benches = sorted(final_benches)
    return final_benches 
    

def main():
    filenames = [filename for filename in sys.argv[1:]]
    # 1. get data from supplied filenames
    bencheset = [load_benches(filename) for filename in filenames]
    nset = [compute_n(benches) for benches in bencheset]
   
    fig = plt.figure()
    all_benches = []
    all_n = sum(nset)
    # 2. Process and normalize data
    all_benches = get_all_benches(bencheset)
    
    filename_base = "/".join(filenames[0].split("/")[:-1]) + "/"
    # 3. generate graph
    make_graph(all_benches, all_n, fig, filename_base + "combined.pdf", filename_base + "combined_stats.txt")
   
def empty_vals(n):
  vals = []
  for jdx in range(n):
      vals.append([])
  return vals

def make_graph(benches, n, fig, outfile, statsfile):
    #for bench in benches:
    #  print(bench)
    idx = 0
    labels = []
    implementations = []    
    vals = empty_vals(n)

    width = (1.0 / (n + 1))  # the width of the bars
    
    ax = fig.add_subplot(111)

    plt.rcParams['pdf.fonttype'] = 42 # true type font
    plt.rcParams['font.family'] = 'Times New Roman'
    plt.rcParams['font.size'] = '8'

    for bench in benches:
      # record the different implementations in order
      if idx < n:
        implementations.append(bench[1])

      ratio = float(bench[2])
      # record the function name
      if idx % n == 0:
          labels.append(bench[0])

      # sort the test cases into bins by implementation
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

    # Clean up graph
    ax.set_xlabel('Sightglass Benchmarks')
    ax.set_ylabel('Relative Execution Time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    ax.set_xticklabels(labels)
    ax.legend( tuple(rects), implementations )
    fig.subplots_adjust(bottom=0.25)

    # Record summary stats and save file
    for i in range(n):
        result_average = sum(vals[i]) / N 
        result_median = median(vals[i])
        with open(statsfile, "a") as myfile:
          myfile.write(f"{implementations[i]} average = {result_average} {implementations[i]} median = {result_median}\n")

    plt.savefig(outfile, format="pdf")


if __name__== "__main__":
  main()

