import numpy as np
import matplotlib.pyplot as plt
import sys
from matplotlib.ticker import FuncFormatter
from collections import defaultdict

def median(lst):
    n = len(lst)
    s = sorted(lst)
    return (sum(s[n//2-1:n//2+1])/2.0, s[n//2])[n % 2] if n else None

def geomean(lst):
    # Geomean is conceptually:
    #   product of all terms in the list, take nth root
    # This can overflow, so it is better to compute it as:
    #   log all terms in the list, arithmetic mean, un-log
    # which is equivalent
    lst = np.array(lst)
    return np.exp(np.mean(np.log(1.0*lst)))  # 1.0* and np.log implicitly lift to lists elementwise

def load_benches(filename):
    with open(filename) as f:
        lines = f.read().split("\n")
    benches = [line.split() for line in lines if line][1:]
    #print(filename)
    #for bench in benches:
    #  print(bench)
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
    # processed_benches = [(bench,implementation,median)]
    for benches in bencheset:
        processed_benches = [bench[:2] + [bench[3]] for bench in benches]
        all_benches.extend(processed_benches)

    # Get raw execution times for reference implementation
    ref_performance = {}
    for bench in all_benches:
      if bench[1].startswith("1."):
        ref_performance[bench[0]] = float(bench[2]) 

    #Normalize benchmarks
    final_benches = []
    for bench in all_benches:
      name = bench[0]
      t = float(bench[-1]) / ref_performance[name]
      final_benches.append(bench[:2] + [t])

    # Remove reference implementation from graphs
    final_benches = sorted([bench for bench in final_benches if not bench[1].startswith("1.")])
    #print("All benches:")

    benchmap = defaultdict(list)
    for bench in final_benches:
        #print(bench)
        _,impl,t = bench
        benchmap[impl].append(t)

    print(benchmap)
    for impl,times in benchmap.items():
        #print(name, geomean(times))
        final_benches.append(["~Geomean", impl, geomean(times)])
        
    final_benches = sorted(final_benches)
    #assert(len(final_benches) % 28 == 0)
    #print(len(final_benches) / 28)
    for bench in final_benches:
        print(bench)
    return final_benches 
    
def load_benches_from_files(filenames):
    #filenames = [filename for filename in sys.argv[1:]]
    # 1. get data from supplied filenames
    bencheset = [load_benches(filename) for filename in filenames]
    nset = [compute_n(benches) for benches in bencheset]
    print("==========>", nset)
    all_benches = []
    all_n = sum(nset)
    # 2. Process and normalize data
    all_benches = get_all_benches(bencheset)
    return all_n-1,all_benches # n reduced by 1 since we remove reference 

def main(filenames, use_percent=False):

    #filenames = sys.argv[1:]
    all_n,all_benches = load_benches_from_files(filenames)
    #print(all_n)
    filename_base = "/".join(filenames[0].split("/")[:-1]) + "/"
    # 3. generate graph
    fig = plt.figure()
    make_graph(all_benches, all_n, fig, filename_base + "combined.pdf", filename_base + "combined_stats.txt", use_percent=use_percent)
   
def empty_vals(n):
  vals = []
  for jdx in range(n):
      vals.append([])
  return vals

def make_graph(benches, n, fig, outfile, statsfile, use_percent):
    #for bench in benches:
    #  print(bench)
    print(n)
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
        implementations.append(bench[1].split(".")[1])

      ratio = float(bench[2])
      # record the function name
      if idx % n == 0:
          labels.append(bench[0])

      # sort the test cases into bins by implementation
      for edx in range(n):
          if idx % n == edx:
              vals[edx].append(ratio)
      idx += 1
    
    print("Implementations Found: ", implementations)
    N = len(labels)
    ind = np.arange(N)
    labels = tuple(labels)

    rects = []
    print(vals)
    for idx,val in enumerate(vals):
      rects.append(ax.bar(ind + width*idx, val, width))

    # Clean up graph
    ax.set_xlabel('Sightglass Benchmarks')
    if use_percent:
         ax.set_ylabel('Execution overhead')
    else:
        ax.set_ylabel('Relative Execution Time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    plt.axhline(y=1.0, color='black', linestyle='dashed')

    plt.ylim(ymin=.5)
    ymax = 3.0
    #if use_percent:
    #    ymax = ymax + 1.0
    plt.ylim(ymax=ymax + 0.1)
    plt.axhline(y=ymax, color='black', linewidth=0.75)
    #print( "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^", plt.gca().spines["top"].set_visible("false"))
    plt.gca().spines["top"].set_visible(False)
    #print("usePercent vals = ", vals)
    for vidx,impl in enumerate(vals):
        for benchnum,xstart in enumerate(ind):
            #print(impl[benchnum])
            if impl[benchnum] < ymax:
                continue
            #print("continuing")
            vlabel = '{:.0%}'.format(impl[benchnum]-1.0)
            # ind = benchmar # (start of bars) 
            #print("label ================= ", impl, ind, width, vidx, ind + width*vidx)
            plt.annotate(vlabel,   # this is the text
                (xstart + width*vidx, ymax + 0.1),  
                textcoords="offset points", # how to position the text
                xytext=(0, (3 if benchnum % 2 == 0 else 8) ), # distance from text to points (x,y)
                ha='center', size=5.5) # horizontal alignment can be left, right or

    if use_percent:
      ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y-1.0))) 

    ax.set_xticklabels(labels)
    plt.locator_params(axis='y', nbins=10)
    ax.legend( tuple(rects), implementations, prop={'size': 5.5} )
    #fig.subplots_adjust(bottom=0.05)
    plt.subplots_adjust(top = 1, bottom = 0, right = 1, left = 0, 
            hspace = 0, wspace = 0)
    plt.margins(0,0)

    # Record summary stats and save file
    for i in range(n):
        result_geomean = geomean(vals[i])
        result_median = median(vals[i])
        with open(statsfile, "a") as myfile:
          myfile.write(f"{implementations[i]} geomean = {result_geomean} {implementations[i]} median = {result_median}\n")

    plt.tight_layout()
    plt.savefig(outfile, format="pdf", bbox_inches="tight", pad_inches=0)



def test3(filenames):
    f1,f2,f3 = filenames
    all_n1,all_benches1 = load_benches_from_files([f1,f2,f3])
    all_n2,all_benches2 = load_benches_from_files([f1,f3,f2])
    all_n3,all_benches3 = load_benches_from_files([f2,f1,f3])
    all_n4,all_benches4 = load_benches_from_files([f2,f3,f1])
    all_n5,all_benches5 = load_benches_from_files([f3,f1,f2])
    all_n6,all_benches6 = load_benches_from_files([f3,f2,f1])
    assert(all_n1 == all_n2)
    assert(all_n1 == all_n3)
    assert(all_n1 == all_n4)
    assert(all_n1 == all_n5)
    assert(all_n1 == all_n6)

    assert(all_benches1 == all_benches2)
    assert(all_benches1 == all_benches3)
    assert(all_benches1 == all_benches4)
    assert(all_benches1 == all_benches5)
    assert(all_benches1 == all_benches6)

    print("All tests passed")



if __name__== "__main__":
    #parser = argparse.ArgumentParser(description='Graph Sightglass Results')
    #parser.add_argument('--usePercent', dest='usePercent', default=False, action='store_true')
    #args = parser.parse_args()

  if sys.argv[1] == "--usePercent":
    filenames = sys.argv[2:]
    use_percent = True 
  else:
    filenames = sys.argv[1:]
    use_percent = False

  if len(filenames) == 3:
      test3(filenames)

  main(filenames, use_percent=use_percent)

