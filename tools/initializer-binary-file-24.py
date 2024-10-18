def generate_binary_file(num_entries=4096, bits_per_channel=12):
    with open('initializer.mem', 'w') as f:
        for i in range(num_entries):
            # Convert i to a 12-bit value
            value = i & 0xFFF
            # Create a 24-bit entry with the same 12-bit value for both channels
            binary = format(value, '012b') + format(value, '012b')
            f.write(binary + '\n')

generate_binary_file()

print("Binary file 'initializer.mem' has been generated.")
