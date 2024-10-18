import struct

def generate_binary_stream(num_entries=4096):
    with open('initializer_stream.bin', 'wb') as f:
        for i in range(num_entries):
            # Convert i to a 12-bit value
            value = i & 0xFFF
            # Pack the same 12-bit value twice into a 24-bit (3-byte) entry
            packed = struct.pack('>I', (value << 12) | value)[1:]
            f.write(packed)

generate_binary_stream()

print("Binary stream file 'initializer_stream.bin' has been generated.")
