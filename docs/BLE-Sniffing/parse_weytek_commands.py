import struct

print('=== WEY-TEK HD SCALE - COMMAND ANALYSIS ===')
print()

# Commands we saw:
# 4c = 'L' - likely "Link" or start streaming
# 41 = 'A' - likely "Ack" or configure
# 49 = 'I' - likely "Init" 
# 4f = 'O' - ?
# 55 = 'U' - likely "Unit" change (byte 10 changes: 00=lb, 01=lb:oz, 02=kg, 03=oz)
# 57 = 'W' - Weight data (response)

print('COMMAND BYTES (ASCII interpretation):')
print('  0x4C = "L" - Start link/streaming')
print('  0x41 = "A" - Acknowledge/configure')
print('  0x49 = "I" - Initialize')
print('  0x4F = "O" - Zero/tare?')
print('  0x55 = "U" - Unit change')
print('  0x57 = "W" - Weight data (notification)')
print()

# The 0x55 (Unit) commands we saw:
# aa aa aa aa 55 00 00 00 00 00 02 57 00  -> set to kg (02)
# aa aa aa aa 55 00 00 00 00 00 03 58 00  -> set to oz (03)  
# aa aa aa aa 55 00 00 00 00 00 00 55 00  -> set to lb (00)
# aa aa aa aa 55 00 00 00 00 00 01 56 00  -> set to lb:oz (01)

print('UNIT COMMANDS (byte 10):')
print('  0x00 = lb (pounds)')
print('  0x01 = lb:oz (pounds and ounces)')
print('  0x02 = kg (kilograms)')
print('  0x03 = oz (ounces)')
print()

# Checksum analysis - byte 11 appears to be sum of cmd + byte10
# 55 + 02 = 57
# 55 + 03 = 58
# 55 + 00 = 55
# 55 + 01 = 56
print('CHECKSUM: byte[11] = byte[4] + byte[10]')
print()

# 0x4F = Zero/Tare command
print('ZERO/TARE COMMAND:')
print('  aa aa aa aa 4f 00 00 00 00 00 00 4f 00')
print()

print('=== FINAL PROTOCOL FOR IMPLEMENTATION ===')
print()
print('Service UUID: E3B744F3-4309-4A3A-B877-CCACD9EFB97D')
print('Characteristic UUID: Need to discover, handle 0x0111')
print()
print('INIT (after connection):')
print('  1. Enable notifications (write 01 00 to CCCD)')
print('  2. Send: aa aa aa aa 4c 00 00 00 00 00 00 4c 00')
print('  3. Send: aa aa aa aa 41 00 00 00 00 00 00 41 00')
print('  4. Send: aa aa aa aa 49 00 00 00 00 00 00 49 00')
print()
print('ZERO/TARE:')
print('  Send: aa aa aa aa 4f 00 00 00 00 00 00 4f 00')
print()
print('PARSE WEIGHT (0x57 response):')
print('  if data[4] == 0x57:')
print('    weight_raw = int32_le(data[6:10])')
print('    ounces = weight_raw / 1000.0')
print('    stable = (data[5] == 0x02)')
