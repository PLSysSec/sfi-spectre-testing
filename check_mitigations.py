#!/usr/bin/env python3
import sys
import os
import re
import argparse

################### Utilties ###################

class bcolors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"
    UNDERLINE = "\033[4m"

def str2bool(v):
    if isinstance(v, bool):
       return v
    if v.lower() in ('yes', 'true', 't', 'y', '1'):
        return True
    elif v.lower() in ('no', 'false', 'f', 'n', '0'):
        return False
    else:
        raise argparse.ArgumentTypeError('Boolean value expected.')

################### Inst parsing ###################

# 0000000000000000 <guest_func_26>:
func_pattern = re.compile("\s*[0-9a-fA-F]{16} \<.*?\>:\s*\n?")

def is_function(line):
    match = func_pattern.fullmatch(line)
    return match

def is_end_of_function(line):
    return line == "" or line == "\n"

func_name_pattern = re.compile(".*?\<(.*)\>")

def get_func_name(line):
    match = func_name_pattern.search(line)
    return match.group(1)

func_offset_pattern = re.compile("([0-9a-fA-F]+) .*")

def get_func_offset(line):
    match = func_offset_pattern.search(line)
    hex_str = "0x" + match.group(1)
    return int(hex_str, 0)

instruction_pattern = re.compile("\s*[0-9a-fA-F]+:\t([0-9a-fA-F][0-9a-fA-F]\s+)+.*\n?")

#    3633:	75 a1                	jne    35d6 <guest_func_24+0x35d6>
def is_instruction(line):
    match = instruction_pattern.fullmatch(line)
    return match

instruction_size_pattern = re.compile("\s*[0-9a-fA-F]+:\s+(([0-9a-fA-F]{2}\s)+)")

def get_instruction_size(line):
    match = instruction_size_pattern.search(line)
    byte_vals = match.group(1)
    bytes_len = byte_vals.count(" ")
    return bytes_len

#    3633:	75 a1                	jne    35d6 <guest_func_24+0x35d6>
jump_pattern = re.compile(".*?\t.*?\tj.*\n?")
#     2e9b:	e9 d0 fe ff ff       	jmpq   2d70 <.plt>
#     3030: ff 25 7a 70 21 00       jmpq   *0x21707a(%rip) 
uncond_fixed_jump_addr1 = "([0-9a-fA-F]+)"
uncond_fixed_jump_addr2 = "(\*0x[0-9a-fA-F]+\(%rip\))"
uncond_fixed_jump = re.compile(".*?\t.*?\tjmp[a-z]*\s+(" + uncond_fixed_jump_addr1 + "|" + uncond_fixed_jump_addr2 + ").*\n?")

def is_jump_instruction(line):
    match = jump_pattern.fullmatch(line)
    uncond_match = uncond_fixed_jump.fullmatch(line)
    if uncond_match:
        return None
    return match

#     d57:	41 ff e7             	jmpq   *%r15
indirect_jump_pattern = re.compile(".*?\t.*?\tj[a-z]*\s+\*%r.*\n?")
def is_indirect_jump_instruction(line):
    match = indirect_jump_pattern.fullmatch(line)
    return match

# 7874:	ff d0                	callq  *%rax
indirect_call_pattern = re.compile(".*?\t.*?\tcall[a-z]*\s+\*%r.*\n?")
def is_indirect_call_instruction(line):
    match = indirect_call_pattern.fullmatch(line)
    return match

offset_pattern = re.compile("\s*([0-9a-fA-F]+):.*")

def get_line_offset(line):
    match = offset_pattern.search(line)
    hex_str = "0x" + match.group(1)
    return int(hex_str, 0)

# assigned later
def matches_function(func_name, func_match_pat):
    match = func_match_pat.fullmatch(func_name)
    return match

#    8f88:	c3                   	retq
ret_pattern = re.compile(".*?\t.*?\tret.*\n?")
def is_ret_instruction(line):
    match = ret_pattern.fullmatch(line)
    return match

def is_retpoline(function_name):
    return function_name.find("retpoline") >= 0

################### Logging ###################

def print_ok(out_str, loginfo):
    if loginfo:
        print(bcolors.OKGREEN + out_str + bcolors.ENDC)

error_count = 0
def print_error(out_str, limit):
    print(bcolors.FAIL + out_str + bcolors.ENDC)
    global error_count
    error_count = error_count + 1
    if limit >= 0 and error_count >= limit:
        print("At least " + str(limit) + " violations")
        print("Note some spurious errors exist as lucet appends data to the end of functions. Thus if you see a disallowed instruction after the last ret of a function, please ignore this")
        sys.exit(1)

################### Program ###################

def check_alignment(args, line, line_num, function_name, alignment_block, offset, expected_align):
    curr_align = offset % alignment_block
    out_str = args.input_file + ":" + str(line_num) + \
        " Func: " + function_name + \
        " Aligned: " + str(curr_align) + "/" + str(alignment_block) + \
        " || " + line
    if curr_align != expected_align:
        print_error(out_str, args.limit)
    else:
        print_ok(out_str, args.loginfo)

def check_within_tblock(args, line, line_num, function_name, offset):
    inst_size = get_instruction_size(line)
    tblock_size = args.spectre_tblock_size
    space_left_in_tblock = tblock_size - (offset % tblock_size)
    if space_left_in_tblock < inst_size:
        out_str = args.input_file + ":" + str(line_num) + \
        " Func: " + function_name + \
        " Instrucion not within transaction block"
        print_error(out_str, args.limit)


STATE_SCANNING = 0
STATE_FOUND_FUNCTION = 1

def process_line(args, line, line_num, state, function_name):
    if state == STATE_SCANNING and is_function(line) and matches_function(get_func_name(line), args.func_match_pat):
        state = STATE_FOUND_FUNCTION
        function_name = get_func_name(line)
        if args.spectre_function_align_enable:
            alignment_block = args.spectre_tblock_size * args.spectre_tblocks_in_ablock
            offset = get_func_offset(line)
            check_alignment(args, line, line_num, function_name, alignment_block, offset, 0)
    elif state == STATE_FOUND_FUNCTION and is_end_of_function(line):
        state = STATE_SCANNING
        function_name = ""
    elif state == STATE_FOUND_FUNCTION and is_instruction(line):
        offset = get_line_offset(line)
        alignment_block = args.spectre_tblock_size
        if args.spectre_tblock_enable:
            check_within_tblock(args, line, line_num, function_name, offset)
        # todo check for interesting instructions
    return (state, function_name)

def scan_file(args):
    state = STATE_SCANNING
    function_name = ""

    with open(args.input_file, "r") as f:
        line_num = 0
        for line in f:
            line_num = line_num + 1
            if line.strip() == "...":
                continue
            (state, function_name) = process_line(args, line, line_num, state, function_name)

def main():
    os.chdir(os.path.dirname(sys.argv[0]))
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter, add_help=True)
    parser.add_argument("input_file", type=str, help="Asm file to check")
    parser.add_argument("--function_filter", type=str, default="*", help="Function name to check")
    parser.add_argument("--limit", type=int, default=-1, help="Stop at `limit` errors")
    parser.add_argument("--loginfo", type=str2bool, default=False, help="Print log level information")
    parser.add_argument("--spectre-tblock-size", type=int, default=32, help="Value used as the bundle size for instructions---similar to native client.")
    parser.add_argument("--spectre-tblocks-in-ablock", type=int, default=4, help="Number of transaction blocks in alignment block. Alignment blocks help align instructions.")
    parser.add_argument("--spectre-function-align-enable", type=str2bool, default=True, help="Whether to align the each function.")
    parser.add_argument("--spectre-tblock-enable", type=str2bool, default=True, help="Whether to align the each function.")
    args = parser.parse_args()
    args.func_match_pat = re.compile(args.function_filter.replace('*', '.*'))

    scan_file(args)

    if error_count != 0:
        print("Note some spurious errors exist as lucet appends data to the end of functions. Thus if you see a disallowed instruction after the last ret of a function, please ignore this\n")
        print("Error Count: " + str(error_count))
        sys.exit(1)


main()