import struct
from collections import Counter

with open('weytek_extracted/FS/data/log/bt/btsnoop_hci.log', 'rb') as f:
    f.read(16)
    
    all_weights = []
    
    while True:
        pkt_header = f.read(24)
        if len(pkt_header) < 24:
            break
        orig_len, incl_len, flags, drops, timestamp = struct.unpack('>IIIIQ', pkt_header)
        data = f.read(incl_len)
        if len(data) < incl_len:
            break
        
        is_rx = (flags & 0x01) == 1
        
        if len(data) > 9 and data[0] == 0x02:
            acl_data = data[1:]
            if len(acl_data) < 8:
                continue
            l2cap_cid = struct.unpack('<H', acl_data[6:8])[0]
            
            if l2cap_cid == 0x0004 and len(acl_data) > 8:
                att_data = acl_data[8:]
                if len(att_data) < 1:
                    continue
                    
                att_opcode = att_data[0]
                
                if att_opcode == 0x1B and is_rx and len(att_data) >= 13:
                    att_value = att_data[3:]
                    
                    if len(att_value) >= 13 and att_value[4] == 0x57:
                        weight = struct.unpack('<i', att_value[6:10])[0]
                        byte10 = att_value[10]
                        all_weights.append((weight, byte10))

# Filter reasonable values
reasonable = [(w, b) for w, b in all_weights if -50000 < w < 500000]

print('=== WEY-TEK HD WEIGHT INTERPRETATION ===')
print()
print('Assuming: value / 1000 = ounces (confirmed by 7oz item)')
print()

weight_counts = Counter([w[0] for w in reasonable])

print('All unique weight readings:')
for val, count in sorted(weight_counts.items()):
    oz = val / 1000
    grams = oz * 28.3495
    lbs = oz / 16
    print(f'  {val:8} ({count:3}x) = {oz:8.3f} oz = {grams:8.1f}g = {lbs:.3f}lbs')

print()
print('Most stable: 7000 = 7.000 oz (user confirmed 7oz item)')
print()

# Byte 10 analysis
print('Byte 10 (unit indicator?):')
b10_groups = {}
for w, b10 in reasonable:
    if b10 not in b10_groups:
        b10_groups[b10] = []
    b10_groups[b10].append(w)

for b10, weights in sorted(b10_groups.items()):
    print(f'  0x{b10:02x}: {len(weights)} readings')
