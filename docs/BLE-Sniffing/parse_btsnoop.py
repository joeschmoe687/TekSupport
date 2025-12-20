#!/usr/bin/env python3
"""
Parse btsnoop_hci.log to extract BLE ATT Write commands
Specifically looking for writes to Testo fff1 characteristic
"""
import struct
import sys

def parse_btsnoop(filename):
    with open(filename, 'rb') as f:
        # Read header
        magic = f.read(8)
        if magic != b'btsnoop\x00':
            print("Not a valid btsnoop file")
            return
        
        version, datalink = struct.unpack('>II', f.read(8))
        print(f"btsnoop version: {version}, datalink type: {datalink}")
        
        packet_num = 0
        att_writes = []
        
        while True:
            # Read packet header (24 bytes)
            header = f.read(24)
            if len(header) < 24:
                break
            
            orig_len, incl_len, flags, drops, timestamp = struct.unpack('>IIIIQ', header)
            
            # Read packet data
            data = f.read(incl_len)
            if len(data) < incl_len:
                break
            
            packet_num += 1
            
            # HCI packet type is first byte
            if len(data) < 1:
                continue
            
            hci_type = data[0]
            
            # We're interested in ACL data packets (type 0x02)
            if hci_type == 0x02 and len(data) > 9:
                # ACL header: handle(2) + length(2), then L2CAP: length(2) + CID(2)
                # Skip HCI type byte
                acl_data = data[1:]
                if len(acl_data) < 8:
                    continue
                
                # Parse ACL header
                handle_flags, acl_len = struct.unpack('<HH', acl_data[:4])
                handle = handle_flags & 0x0FFF
                
                # Parse L2CAP header  
                l2cap_len, l2cap_cid = struct.unpack('<HH', acl_data[4:8])
                
                # CID 0x0004 = ATT (Attribute Protocol)
                if l2cap_cid == 0x0004 and len(acl_data) > 8:
                    att_data = acl_data[8:]
                    if len(att_data) < 1:
                        continue
                    
                    att_opcode = att_data[0]
                    
                    # ATT Write Request = 0x12, Write Command = 0x52
                    if att_opcode in (0x12, 0x52) and len(att_data) >= 3:
                        att_handle = struct.unpack('<H', att_data[1:3])[0]
                        att_value = att_data[3:]
                        
                        is_sent = (flags & 0x01) == 0  # Bit 0: 0=sent, 1=received
                        direction = "TX" if is_sent else "RX"
                        
                        op_name = "Write Request" if att_opcode == 0x12 else "Write Command"
                        hex_value = ' '.join(f'{b:02x}' for b in att_value)
                        
                        att_writes.append({
                            'packet': packet_num,
                            'direction': direction,
                            'handle': att_handle,
                            'opcode': op_name,
                            'value': hex_value,
                            'raw': list(att_value)
                        })
                        
                        print(f"[{packet_num}] {direction} {op_name} handle=0x{att_handle:04x}: {hex_value}")
        
        print(f"\n{'='*60}")
        print(f"Total packets: {packet_num}")
        print(f"ATT Write operations: {len(att_writes)}")
        
        # Find unique write sequences (potential init commands)
        if att_writes:
            print(f"\n{'='*60}")
            print("Unique TX write values (potential init commands):")
            seen = set()
            for w in att_writes:
                if w['direction'] == 'TX':
                    val = w['value']
                    if val not in seen:
                        seen.add(val)
                        print(f"  Handle 0x{w['handle']:04x}: [{val}]")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python parse_btsnoop.py <btsnoop_hci.log>")
        sys.exit(1)
    parse_btsnoop(sys.argv[1])
