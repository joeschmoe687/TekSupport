import struct

print('=== WEY-TEK HD SCALE - SERVICE UUID ===')
print()

# From the advertising data we saw:
# 7d b9 ef d9 ac cc 77 b8 3a 4a 09 43 f3 44 b7 e3
# This is a 128-bit UUID in little-endian

uuid_bytes = bytes([0x7d, 0xb9, 0xef, 0xd9, 0xac, 0xcc, 0x77, 0xb8, 
                    0x3a, 0x4a, 0x09, 0x43, 0xf3, 0x44, 0xb7, 0xe3])

# Convert to standard UUID format (big-endian)
uuid_le = uuid_bytes[::-1]  # Reverse for display
uuid_str = '-'.join([
    uuid_le[0:4].hex(),
    uuid_le[4:6].hex(),
    uuid_le[6:8].hex(),
    uuid_le[8:10].hex(),
    uuid_le[10:16].hex()
])

# Actually the format in advertising is already split
# Let's look at the raw bytes again
print('From advertising data:')
print('Raw bytes:', ' '.join(f'{b:02x}' for b in uuid_bytes))
print()

# The UUID is stored in little-endian in BLE advertising
# Standard format: E3B744F3-4309-4A3A-B877-CCACD9EFB97D
uuid_parts = [
    uuid_bytes[15:11:-1].hex(),  # first 4 bytes reversed
    uuid_bytes[11:9:-1].hex(),   # next 2 bytes reversed
    uuid_bytes[9:7:-1].hex(),    # next 2 bytes reversed
    uuid_bytes[7:5:-1].hex(),    # next 2 bytes
    uuid_bytes[5::-1].hex()      # last 6 bytes reversed
]

print('Trying standard UUID reversal:')
# Actually simpler - just reverse the whole thing
uuid_full = uuid_bytes[::-1]
formatted = f'{uuid_full[0:4].hex()}-{uuid_full[4:6].hex()}-{uuid_full[6:8].hex()}-{uuid_full[8:10].hex()}-{uuid_full[10:16].hex()}'
print(f'Service UUID: {formatted.upper()}')

print()
print('=== COMPLETE PROTOCOL SUMMARY ===')
print()
print('Device Name Pattern: Contains "Wey" or starts with scale MAC')
print('Service UUID:', formatted.upper())
print('Characteristic Handle: 0x0111 (read/write/notify)')
print('CCCD Handle: 0x0112 (enable notifications)')
print()
print('INIT SEQUENCE:')
print('  1. Write 0x01 0x00 to handle 0x0112 (enable notifications)')
print('  2. Write aa aa aa aa 4c 00 00 00 00 00 00 4c 00 to 0x0111')
print('  3. Write aa aa aa aa 41 00 00 00 00 00 00 41 00 to 0x0111')
print('  4. Write aa aa aa aa 49 00 00 00 00 00 00 49 00 to 0x0111')
print()
print('DATA FORMAT (notifications on 0x0111):')
print('  Bytes 0-3:  aa aa aa aa (header)')
print('  Byte 4:     Command (0x57 = weight data)')
print('  Byte 5:     Flags (0x02 = stable, 0x03 = unstable)')
print('  Bytes 6-9:  Weight (32-bit LE, value/1000 = ounces)')
print('  Byte 10:    Unit indicator? (0x00 = oz)')
print('  Bytes 11-12: Checksum?')
print()
print('WEIGHT CONVERSION:')
print('  ounces = int32_le(bytes[6:10]) / 1000.0')
print('  grams = ounces * 28.3495')
print('  pounds = ounces / 16.0')
