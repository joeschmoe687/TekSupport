#!/usr/bin/env python3
"""
Parse live Testo probe data from HCI log
Extracts pressure and temperature readings from T549i and T115i probes
"""

import subprocess
import struct
import sys

def parse_testo_packet(hex_dump_lines):
    """Parse a Testo packet from tshark hex dump output"""
    # Combine hex dump lines into single byte string
    hex_bytes = []
    for line in hex_dump_lines:
        # Parse hex dump format: "0000  04 3e 2d 0d 01 1b 00 00..."
        parts = line.strip().split('  ')
        if len(parts) >= 2:
            hex_part = parts[1].split('   ')[0]  # Get hex before ASCII
            hex_bytes.extend(hex_part.split())
    
    # Convert to bytes
    try:
        data = bytes.fromhex(''.join(hex_bytes))
    except:
        return None
    
    # HCI packet structure:
    # [0] = 0x04 (HCI Event)
    # [1] = 0x3e (LE Meta Event)
    # [2] = Length
    # [3] = 0x0d (LE Advertising Report)
    # [4] = Num reports
    # [5] = Event type
    # [6] = Address type
    # [7-12] = BD Address
    # [13] = Data length
    # [14+] = Advertising data
    
    if len(data) < 20:
        return None
    
    if data[0] != 0x04 or data[1] != 0x3e:
        return None
    
    # Get RSSI (last byte)
    rssi = struct.unpack('b', data[-1:])[0]
    
    # Parse advertising data
    ad_data = data[14:-1]  # Skip header and RSSI
    
    return {
        'raw_data': data.hex(),
        'ad_data': ad_data.hex(),
        'rssi': rssi,
        'data_bytes': ad_data
    }

def decode_testo_measurement(ad_data, device_type):
    """
    Decode Testo measurement from advertising data
    
    Based on ML analysis:
    - T549i (pressure): uint16_le at offset 18, divide by 10 for PSI
    - T115i (temperature): int16_le at offset 8, divide by 10 for °F
    """
    
    if device_type == 'T549i':  # Pressure probe
        if len(ad_data) >= 20:
            # Offset 18-19: pressure value (uint16 little-endian)
            pressure_raw = struct.unpack('<H', ad_data[18:20])[0]
            pressure_psi = pressure_raw / 10.0
            return f"{pressure_psi:.1f} PSI"
    
    elif device_type == 'T115i':  # Temperature probe
        if len(ad_data) >= 10:
            # Offset 8-9: temperature value (int16 little-endian)
            temp_raw = struct.unpack('<h', ad_data[8:10])[0]
            temp_f = temp_raw / 10.0
            return f"{temp_f:.1f} °F"
    
    return "Unknown"

def main():
    hci_log = sys.argv[1] if len(sys.argv) > 1 else "baseline_extracted/FS/data/log/bt/btsnoop_hci.log"
    
    print(f"Parsing Testo probe data from: {hci_log}\n")
    
    # Extract T549i pressure data
    print("=" * 70)
    print("T549i PRESSURE PROBE (SN:49291139)")
    print("=" * 70)
    
    cmd = f'tshark -r {hci_log} -Y \'btcommon.eir_ad.entry.device_name contains "T549i"\' -x 2>/dev/null'
    output = subprocess.check_output(cmd, shell=True, text=True)
    
    lines = output.split('\n')
    packet_lines = []
    packet_count = 0
    
    for line in lines:
        if line.startswith('0000'):
            if packet_lines:
                # Process previous packet
                parsed = parse_testo_packet(packet_lines)
                if parsed:
                    measurement = decode_testo_measurement(parsed['data_bytes'], 'T549i')
                    packet_count += 1
                    if packet_count <= 20:  # Show first 20 readings
                        print(f"  Reading #{packet_count}: {measurement} (RSSI: {parsed['rssi']} dBm)")
            packet_lines = [line]
        elif packet_lines:
            packet_lines.append(line)
    
    # Process last packet
    if packet_lines:
        parsed = parse_testo_packet(packet_lines)
        if parsed:
            measurement = decode_testo_measurement(parsed['data_bytes'], 'T549i')
            packet_count += 1
            if packet_count <= 20:
                print(f"  Reading #{packet_count}: {measurement} (RSSI: {parsed['rssi']} dBm)")
    
    print(f"\nTotal T549i packets: {packet_count}\n")
    
    # Extract T115i temperature data
    print("=" * 70)
    print("T115i TEMPERATURE PROBE (SN:49498664)")
    print("=" * 70)
    
    cmd = f'tshark -r {hci_log} -Y \'btcommon.eir_ad.entry.device_name contains "T115i"\' -x 2>/dev/null'
    output = subprocess.check_output(cmd, shell=True, text=True)
    
    lines = output.split('\n')
    packet_lines = []
    packet_count = 0
    
    for line in lines:
        if line.startswith('0000'):
            if packet_lines:
                # Process previous packet
                parsed = parse_testo_packet(packet_lines)
                if parsed:
                    measurement = decode_testo_measurement(parsed['data_bytes'], 'T115i')
                    packet_count += 1
                    if packet_count <= 20:  # Show first 20 readings
                        print(f"  Reading #{packet_count}: {measurement} (RSSI: {parsed['rssi']} dBm)")
            packet_lines = [line]
        elif packet_lines:
            packet_lines.append(line)
    
    # Process last packet
    if packet_lines:
        parsed = parse_testo_packet(packet_lines)
        if parsed:
            measurement = decode_testo_measurement(parsed['data_bytes'], 'T115i')
            packet_count += 1
            if packet_count <= 20:
                print(f"  Reading #{packet_count}: {measurement} (RSSI: {parsed['rssi']} dBm)")
    
    print(f"\nTotal T115i packets: {packet_count}\n")

if __name__ == '__main__':
    main()
