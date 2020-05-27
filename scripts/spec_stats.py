import sys
from collections import defaultdict
import matplotlib.pyplot as plt
import numpy as np
import argparse
from matplotlib.ticker import FuncFormatter

#prefix = "sfi-spectre-spec/result/"

#result_codes = {}
#times = defaultdict(list)
nameset = set()


def median(lst):
    n = len(lst)
    s = sorted(lst)
    return (sum(s[n//2-1:n//2+1])/2.0, s[n//2])[n % 2] if n else None

def load_data(input_path):
    with open(input_path, 'r') as f:
        data = f.read()
        lines = data.split('\n')
    return lines

def get_lock_num(result_path):
    path = result_path + "/lock.CPU2006"
    with open(path, 'r') as f:
        data = f.read().strip()
    return data

#spec.cpu2006.results.462_libquantum.base.000.reported_time: 502.749075
# spec.cpu2006.ext: wasm_lucet
def summarise(input_path):
    times = {}
    mitigation_name = ""
    #try:
    lines = load_data(input_path)
    #except:
    #    return ("",{})
    for line in lines:
        if "spec.cpu2006.results" in line:
            if ".valid" in line:
                name = line.split('.')[3]
                result_code = line.split()[-1]
                nameset.add(name)
            if ".reported_time" in line:
                name = line.split('.')[3]
                success_code = line.split()[-1]
                times[name] = float(success_code)
        if "spec.cpu2006.ext" in line:
                mitigation_name = line.split()[1]

    return (mitigation_name,times)

def all_times_to_vals(all_times):
    vals = []
    print(all_times)
    for d in all_times.values():
        l = sorted(list(d.items()),key=lambda x: x[0])
        ll = [v for (k,v) in l]
        vals.append(ll)
    return vals


def make_graph(all_times, output_path, use_percent=False):
    fig = plt.figure()
    num_mitigations = len(all_times)
    num_benches = len(next(iter(all_times.values()))) # get any element
    mitigations = list(all_times.keys())
    width = (1.0 / ( (num_mitigations) + 1))        # the width of the bars
    
    ax = fig.add_subplot(111)
    
    vals = all_times_to_vals(all_times)

    ind = np.arange(num_benches)
    labels = tuple(list(next(iter(all_times.values())).keys()))

    print(vals)

    rects = []
    for idx,val in enumerate(vals):
      rects.append(ax.bar(ind + width*idx, val, width))


    ax.set_xlabel('Spec2006 Benchmarks')
    ax.set_ylabel('Relative Execution Time')
    ax.set_xticks(ind+width)
    plt.xticks(rotation=90)

    plt.axhline(y=1.0, color='black', linestyle='dashed')
    plt.ylim(ymin=.8)

    if use_percent:
        ax.yaxis.set_major_formatter(FuncFormatter(lambda y, _: '{:.0%}'.format(y-1.0)))

    ax.set_xticklabels(labels)
    ax.legend( tuple(rects), all_times.keys() )
    fig.subplots_adjust(bottom=0.25)


    for i in range(num_mitigations):
        result_average = sum(vals[i]) / num_benches
        result_median = median(vals[i])
        #print(f"{mitigations[i]} average = {result_average} {mitigations[i]} median = {result_median}")
        with open(output_path + ".stats", "a") as myfile:
            myfile.write(f"{mitigations[i]} average = {result_average} {mitigations[i]} median = {result_median}\n")

    plt.tight_layout()
    plt.savefig(output_path + ".graph", format="pdf")
    '''
    for i in range(num_mitigations):
        result_average = sum(vals[i]) / N 
        result_median = median(vals[i])
        with open(statsfile, "a") as myfile:
          myfile.write(f"{implementations[i]} average = {result_average} {implementations[i]} median = {result_median}\n")

    plt.savefig(outfile, format="pdf")
    '''

    #plt.show()

def get_merged_summary(result_path, n):
    int_input_path = f"{result_path}/CINT2006.{str(n).zfill(3)}.ref.rsf"
    fp_input_path  = f"{result_path}/CFP2006.{str(n).zfill(3)}.ref.rsf"
    name1,int_times = summarise(int_input_path)
    name2,fp_times  = summarise(fp_input_path)
    times = {}
    times.update(int_times)
    times.update(fp_times)
    assert( (not (name1 != "" and name2 == "")) and (name1 == name2) or (name1 == "") or (name2 == ""))
    #print(name1, name2)
    return name1,times

def normalize_times(times):
    normalized_times = defaultdict(dict)
    base_times = times["wasm_lucet"]
    for bench in base_times:
        base_time = base_times[bench]
        for mitigation in times:
            normalized_times[mitigation][bench] = times[mitigation][bench] / base_time 

    return dict(normalized_times)

# "spec.cpu2006.results.464_h264ref.base.000.valid:"
def run(result_path, n, output_path):
    lock_num = int(get_lock_num(result_path))
    all_times = {}
    for idx in range(n):
        name,times = get_merged_summary(result_path, lock_num - n + idx + 1)
        print(name, times)
        all_times[name] = times
   
    normalized_times = normalize_times(all_times)
   
    #{mitigation name -> {}}      --- here is where we cut
    make_graph(normalized_times, output_path)
  

def run_w_filter(result_path, bench_filter, n, use_percent):
    lock_num = int(get_lock_num(result_path))
    all_times = {}
    for idx in range(n):
        name,times = get_merged_summary(result_path, lock_num - n + idx + 1)
        print(name, times)
        all_times[name] = times

    normalized_times = normalize_times(all_times)

    #{mitigation name -> {}}      --- here is where we cut
    for partitioned_times, output_path in bench_filter.partition_benches(normalized_times):
        make_graph(partitioned_times, output_path,  use_percent=use_percent)


class BenchAlias(object):
        """docstring for BenchAlias"""
        def __init__(self, arg):
            name,aliased_as = arg.split(":")
            self.name = name
            self.aliased_as = aliased_as

        def __repr__(self):
            return self.__str__()

        def __str__(self):
            return f"{self.name} -> {self.aliased_as}"

def parse_bench_filter(s):
    d = {}
    benchsets = s.split(";")
    for benchset in benchsets:
        out_path,alias_list = benchset.split("=")
        parsed_aliases = [BenchAlias(alias) for alias in alias_list.split(",")]
        d[out_path] = parsed_aliases

    return d

class BenchFilter(object):
        """docstring for BenchFilter"""
        def __init__(self, s):
                self.filter = parse_bench_filter(s)

        def get_total_mitigation_num(self):
            n = 0
            for bencheset in self.filter.values():
                n += len(bencheset)
            return n

        # normalized times = {mitigation_name -> {bench_name -> time}}
        # bench_aliases = [(name, alias)]
        # result = {mitigation_name (aliased) -> {bench_name -> time}}
        def partition_one(self, normalized_times, bench_aliases):
            d = {}
            for alias in bench_aliases:
                times = normalized_times[alias.name]
                d[alias.aliased_as] = times
            return d

        def partition_benches(self, normalized_times):
            for output_path, bench_aliases in self.filter.items():
                partitioned_benches = self.partition_one(normalized_times, bench_aliases)
                yield partitioned_benches, output_path

        def __str__(self):
            return str(self.filter)

def main():
    parser = argparse.ArgumentParser(description='Graph Spec Results')
    parser.add_argument('-i', dest='input_path', help='input directory (should be a spec2017 results directory)')
    parser.add_argument('--usePercent', dest='usePercent', default=False, action='store_true')
    parser.add_argument("--filter", dest="filter", type=BenchFilter)
    parser.add_argument("-n", dest="n", type=int)
    args = parser.parse_args()
    run_w_filter(args.input_path, args.filter, args.n, use_percent=args.usePercent)


if __name__ == '__main__':
    main()
