import sys
import re

def parse_yosys_log(log_filename):
    """Parses the Yosys log to map both gold and gate names back to their base Verilog names."""
    wire_map = {}
    log_regex = re.compile(r'Presumably equivalent wires: .*?\(\\(.*?)\), .*?\(\\(.*?)\) -> (.*)')
    
    try:
        with open(log_filename, 'r') as f:
            for line in f:
                match = log_regex.search(line)
                if match:
                    gold_raw = match.group(1).split()[0].lstrip('\\')
                    gate_raw = match.group(2).split()[0].lstrip('\\')
                    base_name = match.group(3).strip()
                    
                    wire_map[gold_raw] = (base_name, 'gold')
                    wire_map[gate_raw] = (base_name, 'gate')
    except FileNotFoundError:
        print(f"Warning: Log file '{log_filename}' not found.")
        
    return wire_map

def compare_vcd(vcd_filename, log_filename=None, debug=False):
    wire_map = parse_yosys_log(log_filename) if log_filename else {}
    n_node_regex = re.compile(r'^\\?n\d+$')

    signal_info = {}   
    current_state = {} 
    mismatched_signals = {} 

    header_done = False
    current_time = "0"
    bases_to_check = set()
    pairs_tracked = 0

    with open(vcd_filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            
            # 1. Parse VCD Header
            if not header_done:
                if line.startswith('$var'):
                    parts = line.split()
                    sig_id = parts[3]
                    clean_name = parts[4].lstrip('\\')
                    
                    base = None
                    sig_type = None

                    if clean_name in wire_map:
                        base, sig_type = wire_map[clean_name]
                    elif clean_name.endswith('_gate'):
                        base = clean_name[:-5]
                        sig_type = 'gate'
                    elif clean_name.endswith('_gold'):
                        base = clean_name[:-5]
                        sig_type = 'gold'
                    else:
                        continue 

                    if sig_type == 'gate' and clean_name not in wire_map and n_node_regex.match(clean_name[:-5]):
                        continue

                    if not base:
                        continue

                    signal_info[sig_id] = (base, sig_type)
                    if base not in current_state:
                        current_state[base] = {'gate': 'U', 'gold': 'U'} 

                elif line.startswith('$enddefinitions'):
                    header_done = True
                    for b, states in current_state.items():
                        if 'gate' in states and 'gold' in states:
                            pairs_tracked += 1
                            
                    if debug:
                        print(f"[DEBUG] Successfully tracked {pairs_tracked} signal pairs from VCD & Log.")
            
            # 2. Parse Timestamps and Value Changes
            else:
                if line.startswith('$'):
                    continue 
                
                if line.startswith('#'):
                    # Check mismatches for the previous timestamp block
                    for base in bases_to_check:
                        gate_val = current_state[base]['gate']
                        gold_val = current_state[base]['gold']
                        
                        if debug:
                            print(f"[DEBUG] Time #{current_time} | Signal: {base} | Gate: {gate_val} vs Gold: {gold_val}")

                        if gate_val != 'U' and gold_val != 'U':
                            if gate_val != gold_val and base not in mismatched_signals:
                                mismatched_signals[base] = current_time
                    
                    bases_to_check.clear()
                    current_time = line[1:]
                    continue

                if line.startswith('b') or line.startswith('r') or line.startswith('R'):
                    parts = line.split()
                    val = parts[0][1:] 
                    sig_id = parts[1]
                else:
                    val = line[0]
                    sig_id = line[1:]

                if sig_id in signal_info:
                    base, sig_type = signal_info[sig_id]
                    current_state[base][sig_type] = val
                    bases_to_check.add(base)
                    
        # Check final timestep
        for base in bases_to_check:
            gate_val = current_state[base]['gate']
            gold_val = current_state[base]['gold']
            if gate_val != 'U' and gold_val != 'U':
                if gate_val != gold_val and base not in mismatched_signals:
                    mismatched_signals[base] = current_time

    return mismatched_signals

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python compare_vcd.py <file.vcd> [synthesis.log] [--debug]")
        sys.exit(1)

    vcd_file = sys.argv[1]
    log_file = None
    debug_mode = "--debug" in sys.argv

    for arg in sys.argv[2:]:
        if arg != "--debug":
            log_file = arg

    mismatches = compare_vcd(vcd_file, log_file, debug=debug_mode)

    if mismatches is not None:
        if not mismatches:
            print("All matching Verilog/VHDL signals are equal.")
        else:
            print("\nThe following signals diverged between _gate and _gold:")
            for sig in sorted(mismatches.keys()):
                print(f" - {sig}: First mismatch at timestamp #{mismatches[sig]}")