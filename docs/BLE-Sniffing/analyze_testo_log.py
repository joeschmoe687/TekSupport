#!/usr/bin/env python3
"""
Analyze Testo app log to extract pressure readings for correlation with HCI logs
"""
import json
from datetime import datetime

def analyze_testo_log(log_file):
    """Parse and analyze Testo JSON log"""
    print(f"Loading {log_file}...")
    with open(log_file, 'r') as f:
        data = json.load(f)
    print("JSON loaded successfully\n")
    
    # Extract pressure channel
    channels = data.get('channels', [])
    print(f"Found {len(channels)} channels")
    
    for i, channel in enumerate(channels):
        ch_type = channel.get('type', {}).get('name', '')
        unit_name = channel.get('unit', {}).get('name', '')
        
        if 'Pressure' in ch_type or 'psi' in unit_name:
            print(f"\n=== TESTO T549i PRESSURE PROBE ===")
            print(f"Type: {ch_type}")
            print(f"Unit: {unit_name}\n")
            
            # Get pressure data
            values = channel.get('values', [])
            print(f"Total readings: {len(values)}")
            
            # Filter out zero readings and get actual pressure values
            pressure_values = [float(v.get('value', 0)) for v in values if v.get('value', 0) != 0]
            
            if pressure_values:
                print(f"Non-zero readings: {len(pressure_values)}")
                print(f"Pressure range: {min(pressure_values):.1f} - {max(pressure_values):.1f} {unit_name}")
                print(f"Average: {sum(pressure_values)/len(pressure_values):.1f} {unit_name}")
                
                # Show first 10 non-zero readings
                print(f"\n=== FIRST 10 NON-ZERO READINGS ===")
                count = 0
                for i, v in enumerate(values):
                    val = v.get('value', 0)
                    if val != 0:
                        print(f"  Index {i}: {val:.1f} {unit_name}")
                        count += 1
                        if count >= 10:
                            break
                
                # Show last 10 readings
                print(f"\n=== LAST 10 READINGS ===")
                for i in range(max(0, len(values)-10), len(values)):
                    val = values[i].get('value', 0)
                    print(f"  Index {i}: {val:.1f} {unit_name}")
                
                # Generate correlation targets
                print(f"\n=== CORRELATION TARGETS FOR HCI LOG ===")
                print(f"Look for these pressure values in btsnoop_hci.log:")
                
                # Sample some distinct values across the range
                sample_indices = [
                    len(values)//4,      # ~25% through
                    len(values)//2,      # ~50% through
                    3*len(values)//4,    # ~75% through
                ]
                
                print(f"\nSample readings to correlate:")
                for idx in sample_indices:
                    if idx < len(values):
                        val_psi = values[idx].get('value', 0)
                        if val_psi > 0:
                            val_mbar = val_psi / 0.0145038
                            raw_uint16 = int(val_mbar * 10)
                            print(f"  Index {idx}: {val_psi:.1f} PSI = {val_mbar:.1f} mbar = Uint16({raw_uint16})")

if __name__ == '__main__':
    import sys
    log_file = sys.argv[1] if len(sys.argv) > 1 else 'Testo/AppLogs/2025-12-23-testo_2temp_1Pressure.txt'
    analyze_testo_log(log_file)
