#!/usr/bin/env python3
"""
Validate Fieldpiece pressure parsing formulas against CSV app export data
"""
import csv
import os
from datetime import datetime

def validate_fieldpiece_pressure():
    """Test Fieldpiece BG pressure probe parsing"""
    
    print("=== FIELDPIECE PRESSURE VALIDATION ===\n")
    
    # Test both Blue (suction/low side) and Red (discharge/high side) probes
    csv_files = [
        ('Fieldpiece/FPappLogs/22122975_BG_1.csv', 'Blue (Low Side)', 2975),
        ('Fieldpiece/FPappLogs/22122976_BG_0.csv', 'Red (High Side)', 2976),
    ]
    
    for csv_file, label, tool_id in csv_files:
        print(f"\n--- {label} (Tool ID: {tool_id}) ---\n")
        
        if not os.path.exists(csv_file):
            print(f"ERROR: {csv_file} not found")
            continue
        
        try:
            with open(csv_file, 'r') as f:
                # Skip metadata rows (first 7 lines)
                for _ in range(7):
                    f.readline()
                
                reader = csv.DictReader(f)
                rows = list(reader)
                
                print(f"Total readings: {len(rows)}")
                
                # Get pressure range (column name has no space before parenthesis)
                pressures = [float(row['Pressure(psig)']) for row in rows if row.get('Pressure(psig)')]
                print(f"Pressure range: {min(pressures):.1f} - {max(pressures):.1f} PSIG")
                print(f"Average: {sum(pressures)/len(pressures):.1f} PSIG")
                
                # Show first/last 3 readings
                print(f"\nFirst 3 readings:")
                for i in range(min(3, len(rows))):
                    if rows[i].get('Pressure(psig)'):
                        print(f"  {rows[i]['Time']}: {rows[i]['Pressure(psig)']} PSIG")
                
                print(f"\nLast 3 readings:")
                for i in range(max(0, len(rows)-3), len(rows)):
                    if rows[i].get('Pressure(psig)'):
                        print(f"  {rows[i]['Time']}: {rows[i]['Pressure(psig)']} PSIG")
                
                # Calculate expected raw values based on formula reverse engineering
                # Current formula in device_registry.dart:
                # (rawValue - 10359) * some_scaling
                # Need to determine correct scaling factor
                
                print(f"\n--- Formula Validation ---")
                print(f"Current hypothesis: rawValue = (pressure_psig / scale) + 10359")
                print(f"Need to correlate with HCI packet data to determine 'scale'")
                
                # Calculate what raw values should be for different scale guesses
                test_scales = [0.01, 0.1, 1.0, 10.0]
                sample_pressure = pressures[0]
                
                print(f"\nSample pressure: {sample_pressure} PSIG")
                print(f"Predicted raw values for different scales:")
                for scale in test_scales:
                    raw = (sample_pressure / scale) + 10359
                    print(f"  scale={scale}: rawValue={raw:.0f}")
                
        except FileNotFoundError:
            print(f"ERROR: {csv_file} not found")
        except Exception as e:
            print(f"ERROR reading {csv_file}: {e}")
    
    # Test temperature probes
    print(f"\n\n=== FIELDPIECE TEMPERATURE VALIDATION ===\n")
    
    temp_files = [
        ('Fieldpiece/FPappLogs/22128975_BF_1.csv', 'Blue Temp', 8975),
        ('Fieldpiece/FPappLogs/22128976_BF_0.csv', 'Red Temp', 8976),
    ]
    
    for csv_file, label, tool_id in temp_files:
        print(f"\n--- {label} (Tool ID: {tool_id}) ---\n")
        
        if not os.path.exists(csv_file):
            print(f"ERROR: {csv_file} not found")
            continue
        
        try:
            with open(csv_file, 'r') as f:
                # Skip metadata rows (first 7 lines)
                for _ in range(7):
                    f.readline()
                
                reader = csv.DictReader(f)
                rows = list(reader)
                
                print(f"Total readings: {len(rows)}")
                
                # Get temp range (column name has no space before parenthesis)
                temps = [float(row['Temperature(°F)']) for row in rows if row.get('Temperature(°F)')]
                print(f"Temperature range: {min(temps):.1f} - {max(temps):.1f} °F")
                print(f"Average: {sum(temps)/len(temps):.1f} °F")
                
                print(f"\nFirst 3 readings:")
                for i in range(min(3, len(rows))):
                    if rows[i].get('Temperature(°F)'):
                        print(f"  {rows[i]['Time']}: {rows[i]['Temperature(°F)']} °F")
                
        except FileNotFoundError:
            print(f"ERROR: {csv_file} not found")
        except Exception as e:
            print(f"ERROR reading {csv_file}: {e}")
    
    # Test psychrometer
    print(f"\n\n=== FIELDPIECE PSYCHROMETER VALIDATION ===\n")
    
    csv_file = 'Fieldpiece/FPappLogs/23075699_BH_0.csv'
    
    if not os.path.exists(csv_file):
        print(f"ERROR: {csv_file} not found")
    else:
        try:
            with open(csv_file, 'r') as f:
                # Skip metadata rows (first 7 lines)
                for _ in range(7):
                    f.readline()
                
                reader = csv.DictReader(f)
                rows = list(reader)
                
                print(f"Total readings: {len(rows)}")
                
                # Get ranges for all parameters (column names have no spaces before parenthesis)
                dry_bulbs = [float(row['DB(°F)']) for row in rows if row.get('DB(°F)')]
                wet_bulbs = [float(row['WB(°F)']) for row in rows if row.get('WB(°F)')]
                # Humidity has % in the value, need to strip it
                humidities = [float(row['RH%'].rstrip('%')) for row in rows if row.get('RH%')]
                
                print(f"Dry Bulb range: {min(dry_bulbs):.1f} - {max(dry_bulbs):.1f} °F")
                print(f"Wet Bulb range: {min(wet_bulbs):.1f} - {max(wet_bulbs):.1f} °F")
                print(f"Humidity range: {min(humidities):.1f} - {max(humidities):.1f} %")
                
                print(f"\nFirst 3 readings:")
                for i in range(min(3, len(rows))):
                    db = rows[i]['DB(°F)']
                    wb = rows[i]['WB(°F)']
                    rh = rows[i]['RH%']
                    print(f"  {rows[i]['Time']}: DB={db}°F, WB={wb}°F, RH={rh}")
                
                print(f"\n--- Formula Validation ---")
                print(f"Current implementation:")
                print(f"  Dry bulb: bytes 13-14 ÷ 10")
                print(f"  Wet bulb: bytes 15-16 ÷ 10")
                print(f"  Humidity: byte 17")
                print(f"\nThese formulas should produce values matching CSV data")
        
        except Exception as e:
            print(f"ERROR reading {csv_file}: {e}")

if __name__ == '__main__':
    validate_fieldpiece_pressure()
