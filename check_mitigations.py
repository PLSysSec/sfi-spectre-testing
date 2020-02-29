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

# 11a5b:	e8 20 62 00 00       	callq  17c80 <guest_func_puts>
# 7874:	ff d0                	callq  *%rax
call_pattern = re.compile(".*?\t.*?\tcall[a-z]*\s+.*\n?")
def is_call_instruction(line):
    match = call_pattern.fullmatch(line)
    return match


offset_pattern = re.compile("\s*([0-9a-fA-F]+):.*")

def get_line_offset(line):
    match = offset_pattern.search(line)
    hex_str = "0x" + match.group(1)
    return int(hex_str, 0)

# assigned later
def matches_function(func_name, func_match_pat, func_match_pat_exclude):
    if func_match_pat_exclude and func_match_pat_exclude.fullmatch(func_name):
        return None
    match = func_match_pat.fullmatch(func_name)
    return match

#    8f88:	c3                   	retq
ret_pattern = re.compile(".*?\t.*?\tret.*\n?")
def is_ret_instruction(line):
    match = ret_pattern.fullmatch(line)
    return match

#  327:	c9                   	leaveq
leave_pattern = re.compile(".*?\t.*?\tleave.*\n?")
def is_leave_instruction(line):
    match = leave_pattern.fullmatch(line)
    return match

# b97:	0f 0b                	ud2
ud2_pattern = re.compile(".*?\t.*?\tud2.*\n?")
def is_ud2_instruction(line):
    match = ud2_pattern.fullmatch(line)
    return match

#2462a:	fe                   	(bad)  
bad_pattern = re.compile(".*?\t.*?\t\(bad\).*\n?")
def is_bad_instruction(line):
    match = bad_pattern.fullmatch(line)
    return match

def is_retpoline(function_name):
    return function_name.find("retpoline") >= 0

function_switch_table_mapping = {}
def add_switch_table_mapping(args, function_name, start_line, end_line, last_valid_inst_line):
    function_switch_table_mapping[function_name] = {
        "start_line": start_line,
        "end_line": end_line,
        "last_valid_inst_line": last_valid_inst_line
    }
    print_ok("End of function: " + function_name + " : " + str(last_valid_inst_line), args.loginfo)

def init_switch_table_mapping(args):
    function_name = ""
    start_line = 0
    last_valid_inst_line = 0
    seen_bad = False
    with open(args.input_file, "r") as f:
        line_num = 0
        for line in f:
            line_num = line_num + 1
            if line.strip() == "...":
                continue
            if is_function(line) and matches_function(get_func_name(line), args.func_match_pat, args.func_match_pat_exclude):
                function_name = get_func_name(line)
                start_line = line_num
                last_valid_inst_line = 0
                seen_bad = False
            if function_name != "" and is_end_of_function(line):
                end_line = line_num
                if last_valid_inst_line == 0:
                    last_valid_inst_line = end_line
                add_switch_table_mapping(args, function_name, start_line, end_line, last_valid_inst_line)
                function_name = ""
            # heuristic if we see a terminator instruction in the function, this is probably not switch table data
            if is_bad_instruction(line):
                seen_bad = True
            if not seen_bad and (is_ret_instruction(line) or is_leave_instruction(line) or is_ud2_instruction(line)):
                last_valid_inst_line = line_num

    if function_name:
        end_line = line_num
        if last_valid_inst_line == 0:
            last_valid_inst_line = end_line
        add_switch_table_mapping(args, function_name, start_line, end_line, last_valid_inst_line)
        function_name = ""

def is_switch_table_instruction(args, target_line_num, function_name):
    last_valid_inst_line = function_switch_table_mapping[function_name]["last_valid_inst_line"]
    return target_line_num > last_valid_inst_line

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

def log_on(args, line, line_num, function_name, msg):
    out_str = args.input_file + ":" + str(line_num) + \
        " Func: " + function_name + \
        " " + msg + \
        " || " + line
    print_ok(out_str, args.loginfo)

def error_on(args, line, line_num, function_name, msg):
    out_str = args.input_file + ":" + str(line_num) + \
        " Func: " + function_name + \
        " " + msg + \
        " || " + line
    print_error(out_str, args.limit)

def check_alignment(args, line, line_num, function_name, alignment_block, offset, expected_align):
    curr_align = offset % alignment_block
    out_str = "Aligned: " + str(curr_align) + "/" + str(alignment_block) + \
        " Expected Align: " + str(expected_align)
    if curr_align != expected_align:
        error_on(args, line, line_num, function_name, out_str)
    else:
        log_on(args, line, line_num, function_name, out_str)

def check_within_tblock(args, line, line_num, function_name, offset):
    inst_size = get_instruction_size(line)
    tblock_size = args.spectre_tblock_size
    space_left_in_tblock = tblock_size - (offset % tblock_size)
    if space_left_in_tblock < inst_size:
        out_str = "Instruction not within transaction block"
        error_on(args, line, line_num, function_name, out_str)

STATE_SCANNING = 0
STATE_FOUND_FUNCTION = 1
STATE_SWITCH_TABLE_DATA = 2

def process_line(args, line, line_num, state, function_name):
    if state == STATE_SCANNING and is_function(line) and matches_function(get_func_name(line), args.func_match_pat, args.func_match_pat_exclude):
        state = STATE_FOUND_FUNCTION
        function_name = get_func_name(line)
        if args.spectre_function_align_enable:
            alignment_block = args.spectre_tblock_size * args.spectre_tblocks_in_ablock
            offset = get_func_offset(line)
            check_alignment(args, line, line_num, function_name, alignment_block, offset, 0)
    elif (state == STATE_FOUND_FUNCTION or state == STATE_SWITCH_TABLE_DATA) and is_end_of_function(line):
        state = STATE_SCANNING
        function_name = ""
    elif state == STATE_FOUND_FUNCTION and is_instruction(line) and args.ignore_switch_table_data and is_switch_table_instruction(args, line_num, function_name):
        state = STATE_SWITCH_TABLE_DATA
    elif state == STATE_FOUND_FUNCTION and is_instruction(line):
        offset = get_line_offset(line)
        if args.spectre_tblock_enable:
            alignment_block = args.spectre_tblock_size
            check_within_tblock(args, line, line_num, function_name, offset)

            if args.spectre_indirect_call_via_jump and is_indirect_call_instruction(line):
                error_on(args, line, line_num, function_name, "Call Indirect function not allowed")

            if is_call_instruction(line):
                inst_size = get_instruction_size(line)
                # instruction needs to end on the last byte of the tblock
                check_alignment(args, line, line_num, function_name, alignment_block, offset + inst_size, 0)

        alignment_block = args.spectre_tblock_size * args.spectre_tblocks_in_ablock
        if args.spectre_indirect_branch_align_enable and is_indirect_jump_instruction(line):
            check_alignment(args, line, line_num, function_name, alignment_block, offset, args.spectre_indirect_branch_align)
        if args.spectre_direct_branch_align_enable and is_jump_instruction(line) and not is_indirect_jump_instruction(line):
            check_alignment(args, line, line_num, function_name, alignment_block, offset, args.spectre_direct_branch_align)
        # todo check for other interesting instructions
    return (state, function_name)

def scan_file(args):
    if args.ignore_switch_table_data:
        init_switch_table_mapping(args)

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
    parser.add_argument("--function_exclude_filter", type=str, default="", help="Functions to exclude")
    parser.add_argument("--limit", type=int, default=-1, help="Stop at `limit` errors")
    parser.add_argument("--loginfo", type=str2bool, default=False, help="Print log level information")
    parser.add_argument("--ignore-switch-table-data", type=str2bool, default=False, help="Do not throw errors when finding switch table data that is stored in the code section with exec permissions")
    parser.add_argument("--spectre-tblock-size", type=int, default=32, help="Value used as the bundle size for instructions---similar to native client.")
    parser.add_argument("--spectre-tblocks-in-ablock", type=int, default=4, help="Number of transaction blocks in alignment block. Alignment blocks help align instructions.")
    parser.add_argument("--spectre-function-align-enable", type=str2bool, default=True, help="Whether to align the each function.")
    parser.add_argument("--spectre-tblock-enable", type=str2bool, default=True, help="Whether to align the each function.")
    parser.add_argument("--spectre-direct-branch-align-enable", type=str2bool, default=True, help="Whether to align direct branches.")
    parser.add_argument("--spectre-direct-branch-align", type=int, default=23, help="What offset to align the direct branch instructions. direct_branch_inst_Offset mod tblock_size == this_value.")
    parser.add_argument("--spectre-indirect-branch-align-enable", type=str2bool, default=True, help="Whether to align the indirect branch instructions.")
    parser.add_argument("--spectre-indirect-branch-align", type=int, default=19, help="What offset to align the indirect branch instructions. indirect_branch_inst_Offset mod tblock_size == this_value.")
    # Disable by default as it is not necessary
    parser.add_argument("--spectre-indirect-call-via-jump", type=str2bool, default=False, help="Whether to replace all indirect calls with jump instructions.")

    args = parser.parse_args()
    args.func_match_pat = re.compile(args.function_filter.replace('*', '.*'))
    args.func_match_pat_exclude = None
    if args.function_exclude_filter:
        args.func_match_pat_exclude = re.compile(args.function_exclude_filter.replace('*', '.*'))

    scan_file(args)

    if error_count != 0:
        print("Error Count: " + str(error_count))
        sys.exit(1)


main()