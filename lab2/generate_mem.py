def hex_to_bin7(hex_str):
    # Convert hex to int, then to 8-bit binary, and keep only the lowest 7 bits
    val = int(hex_str, 16)
    return format(val & 0x7F, '07b')  # Mask to 7 bits, format as binary

def generate_vhdl_init(filename: str):
    with open(filename, 'r') as f:
        lines = [line.strip() for line in f if line.strip() != '']

    print("signal mem : mem_type := (")
    for i, hex_val in enumerate(lines):
        try:
            bin_val = hex_to_bin7(hex_val)
        except ValueError:
            raise ValueError(f"Invalid hex value at line {i + 1}: '{hex_val}'")
        
        comma = ',' if i != len(lines) - 1 else ''
        print(f"    {i} => \"{bin_val}\"{comma}")
    print(");")

if __name__ == "__main__":
    generate_vhdl_init("mem_init.txt")
