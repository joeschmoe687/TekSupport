import struct

print('=== WEY-TEK HD SCALE INIT SEQUENCE ===')
print()

with open('weytek_extracted/FS/data/log/bt/btsnoop_hci.log', 'rb') as f:
    f.read(16)
    
    packet_num = 0
    device_addr = None
    
    # Track all TX writes in order
    tx_writes = []
    
    while True:
        pkt_header = f.read(24)
        if len(pkt_header) < 24:
            break
        orig_len, incl_len, flags, drops, timestamp = struct.unpack('>IIIIQ', pkt_header)
        data = f.read(incl_len)
        if len(data) < incl_len:
            break
        packet_num += 1
        
        is_rx = (flags & 0x01) == 1
        
        # Look for device address in connection
        if len(data) > 0 and data[0] == 0x04:  # HCI Event
            if len(data) > 3 and data[1] == 0x3e:  # LE Meta Event
                subevent = data[3]
                if subevent == 0x01 and len(data) > 12:  # Connection Complete
                    # Peer address at offset 8-13
                    addr = data[8:14]
                    device_addr = ':'.join(f'{b:02X}' for b in reversed(addr))
                    print(f'[{packet_num}] Connection to: {device_addr}')
        
        # ACL data
        if len(data) > 9 and data[0] == 0x02:
            acl_data = data[1:]
            if len(acl_data) < 8:
                continue
            l2cap_cid = struct.unpack('<H', acl_data[6:8])[0]
            
            if l2cap_cid == 0x0004 and len(acl_data) > 8:  # ATT
                att_data = acl_data[8:]
                if len(att_data) < 1:
                    continue
                    
                att_opcode = att_data[0]
                
                # Write Request (0x12) and Write Command (0x52)
                if att_opcode in [0x12, 0x52] and not is_rx:
                    if len(att_data) >= 3:
                        att_handle = struct.unpack('<H', att_data[1:3])[0]
                        att_value = att_data[3:]
                        hex_val = ' '.join(f'{b:02x}' for b in att_value)
                        op = 'Write' if att_opcode == 0x12 else 'WriteCmd'
                        tx_writes.append((packet_num, op, att_handle, att_value, hex_val))

print()
print('=== TX WRITES (INIT COMMANDS) ===')
for pkt, op, handle, value, hex_val in tx_writes[:20]:
    print(f'[{pkt}] {op:8} h=0x{handle:04x}: {hex_val}')

print()
print('=== PROTOCOL SUMMARY ===')
print('Device Address:', device_addr if device_addr else 'Not found')
print()

# The init writes
print('Init Sequence:')
for pkt, op, handle, value, hex_val in tx_writes[:5]:
    if handle == 0x0112:
        print(f'  1. Enable notifications on 0x0112: {hex_val}')
    elif handle == 0x0111:
        print(f'  2. Send command to 0x0111: {hex_val}')
