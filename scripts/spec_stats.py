import sys
from collections import defaultdict
import matplotlib.pyplot as plt
import numpy as np


prefix = "sfi-spectre-spec/result/"

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

def get_lock_num():
    path = prefix + "lock.CPU2006"
    with open(path, 'r') as f:
        data = f.read().strip()
    return data

#spec.cpu2006.results.462_libquantum.base.000.reported_time: 502.749075
# spec.cpu2006.ext: wasm_lucet
def summarise(input_path):
    times = {}
    mitigation_name = ""
    try:
        lines = load_data(input_path)
    except:
        return ("",{})
    for line in lines:
        if "spec.cpu2006.results" in line:
            if ".valid" in line:
                name = line.split('.')[3]
                result_code = line.split()[-1]
                #assert(name not in result_codes)
                #result_codes[name] = result_code
                nameset.add(name)
                #print(name, result_code)
            if ".reported_time" in line:
                name = line.split('.')[3]
                success_code = line.split()[-1]
                times[name] = float(success_code)
                #print(name, success_code)
        if "spec.cpu2006.ext" in line:
                #print(line)
                mitigation_name = line.split()[1]

    #assert(mitigation_name != "")
    return (mitigation_name,times)

def all_times_to_vals(all_times):
    vals = []
    print(all_times)
    for d in all_times.values():
        l = sorted(list(d.items()),key=lambda x: x[0])
        ll = [v for (k,v) in l]
        vals.append(ll)
    return vals



def make_graph(all_times):
    fig = plt.figure()
    num_mitigations = len(all_times)
    num_benches = len(next(iter(all_times.values()))) # get any element
    mitigations = list(all_times.keys())
    width = (1.0 / ( (num_mitigations*num_benches) + 1))        # the width of the bars
    
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

    ax.set_xticklabels(labels)
    ax.legend( tuple(rects), all_times.keys() )
    fig.subplots_adjust(bottom=0.25)


    for i in range(num_mitigations):
        result_average = sum(vals[i]) / num_benches
        result_median = median(vals[i])
        print(f"{mitigations[i]} average = {result_average} {mitigations[i]} median = {result_median}")

    plt.show()

def get_merged_summary(n):
    int_input_path = prefix + f"CINT2006.{n}.ref.rsf"
    fp_input_path = prefix + f"CFP2006.{n}.ref.rsf"
    name1,int_times = summarise(int_input_path)
    name2,fp_times = summarise(fp_input_path)
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
def run():
    lock_num = int(get_lock_num())
    name1,times1 = get_merged_summary(lock_num - 2)
    name2,times2 = get_merged_summary(lock_num - 1)
    name3,times3 = get_merged_summary(lock_num)
    times = {name1 : times1, name2 : times2, name3 : times3}
    print(times)

    normalized_times = normalize_times(times)
    #print(normalized_times)
   
    #{mitigation name -> {}}
    make_graph(normalized_times)
  


def main():
    if len(sys.argv) != 1:
        print("Usage: python spec_stats.py")
        sys.exit()
    run()

if __name__ == '__main__':
    main()