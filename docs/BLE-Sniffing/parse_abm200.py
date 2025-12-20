#!/usr/bin/env python3
"""
Parse btsnoop_hci.log to extract ABM-200 airflow meter data
Looking for notifications from characteristic 961f0005
"""
import struct
import sys
from datetime import datetime

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
        notifications = []
        
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
            
            # ACL data packets (type 0x02)
            if hci_type == 0x02 and len(data) > 9:
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
                    
                    # ATT Handle Value Notification = 0x1B
                    if att_opcode == 0x1B and len(att_data) >= 3:
                        att_handle = struct.unpack('<H', att_data[1:3])[0]
                        att_value = att_data[3:]
                        
                        # Look for 14-byte payloads (ABM-200 data format)
                        if len(att_value) >= 14:
                            hex_value = ' '.join(f'{b:02x}' for b in att_value)
                            
                            # Parse as ABM-200 format
                            bytes_data = bytes(att_value[:14])
                            
                            # Try various interpretations
                            b0_1 = struct.unpack('<H', bytes_data[0:2])[0]
                            b2_3 = struct.unpack('<H', bytes_data[2:4])[0]
                            b4_5 = struct.unpack('<H', bytes_data[4:6])[0]
                            b6_7 = struct.unpack('<H', bytes_data[6:8])[0]
                            b8_9 = struct.unpack('<H', bytes_data[8:10])[0]
                            b10_11 = struct.unpack('<H', bytes_data[10:12])[0]
                            b12_13 = struct.unpack('<H', bytes_data[12:14])[0]
                            
                            notifications.append({
                                'packet': packet_num,
                                'handle': att_handle,
                                'raw': hex_value,
                                'b0_1': b0_1,
                                'b2_3': b2_3,
                                'b4_5': b4_5,
                                'b6_7': b6_7,
                                'b8_9': b8_9,
                                'b10_11': b10_11,
                                'b12_13': b12_13,
                            })
        
        print(f"\nTotal packets: {packet_num}")
        print(f"14-byte notifications found: {len(notifications)}")
        
        # Filter for likely ABM-200 data (looking for patterns)
        # Pressure around 9700 (389.7 inWC), values that look like sensor data
        print("\n" + "="*100)
        print("14-BYTE NOTIFICATIONS (potential ABM-200 data):")
        print("="*100)
        
        for n in notifications[-50:]:  # Last 50
            # Decode with various formulas
            pressure_guess = n['b12_13'] * 0.0401463
            humidity_guess = n['b8_9'] / 5.29
            temp_guess_10_11 = n['b10_11'] * 1.6
            
            print(f"Pkt {n['packet']:6d} | Handle 0x{n['handle']:04x} | {n['raw']}")
            print(f"         b0-1:{n['b0_1']:5d}  b2-3:{n['b2_3']:5d}  b4-5:{n['b4_5']:5d}  b6-7:{n['b6_7']:5d}  b8-9:{n['b8_9']:5d}  b10-11:{n['b10_11']:5d}  b12-13:{n['b12_13']:5d}")
            print(f"         Pressure(b12-13): {pressure_guess:.1f}  Humidity(b8-9): {humidity_guess:.1f}%  Temp(b10-11×1.6): {temp_guess_10_11:.1f}°F")
            print()

if __name__ == '__main__':
    if len(sys.argv) < 2:
        # Default to latest bugreport
        filename = '/Users/joeykeilbarth/Desktop/To_New_Beginnings/TekNeck/Apps/Support/hvac_support_app/docs/BLE-Sniffing/bugreport_latest/FS/data/log/bt/btsnoop_hci.log'
    else:
        filename = sys.argv[1]
    
    print(f"Parsing: {filename}")
    parse_btsnoop(filename)
