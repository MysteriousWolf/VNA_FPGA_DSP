def generate_binary_file(num_entries=4096, bits_per_channel=12, total_bits=32):
    with open('initializer.mem', 'w') as f:
        for i in range(num_entries):
            # Convert i to a 12-bit value
            value = i & 0xFFF
            # Create a 24-bit entry with the same 12-bit value for both channels
            binary_24bit = format(value, '012b') + format(value, '012b')
            # Pad with zeroes on the left to make it 32 bits
            binary_32bit = binary_24bit.zfill(total_bits)
            f.write(binary_32bit + '\n')

generate_binary_file(num_entries=3500)

print("32-bit binary file 'initializer.mem' has been generated.")
