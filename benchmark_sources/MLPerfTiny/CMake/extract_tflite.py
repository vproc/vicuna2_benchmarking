import sys
import re

def main():
    input_file = sys.argv[1]
    output_file = sys.argv[2]

    with open(input_file, 'r') as f:
        content = f.read()

    # Find everything between { and }
    match = re.search(r'\{(.*)\}', content, re.DOTALL)
    if not match:
        print("Could not find array data in", input_file)
        sys.exit(1)

    array_data = match.group(1)
    
    # Extract hex bytes
    hex_values = re.findall(r'0x[0-9a-fA-F]+', array_data)
    
    byte_array = bytearray([int(x, 16) for x in hex_values])

    with open(output_file, 'wb') as f:
        f.write(byte_array)

if __name__ == "__main__":
    main()
