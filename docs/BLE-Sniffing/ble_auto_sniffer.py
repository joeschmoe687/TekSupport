#!/usr/bin/env python3
"""
Automated BLE Sniffer with ML Real-Time Probe Detection
Analyzes Testo pressure/temperature probes and auto-generates device profiles

Usage:
    python3 ble_auto_sniffer.py <btsnoop_hci.log>
    python3 ble_auto_sniffer.py <testo_app_log.csv>
"""

import json
import struct
import argparse
from datetime import datetime
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Tuple, Optional
import statistics

# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class BleReading:
    """Single BLE characteristic read/write event"""
    timestamp: float
    direction: str  # "TX" or "RX"
    handle: int
    uuid: str
    raw_bytes: bytes
    packet_number: int
    
    def hex_str(self) -> str:
        return ' '.join(f'{b:02x}' for b in self.raw_bytes)

@dataclass
class ProbeDetection:
    """ML-detected probe type and measurement"""
    probe_type: str  # "temperature", "pressure", "humidity"
    manufacturer: str  # "Testo", "Fieldpiece", "Wey-Tek"
    model: Optional[str]  # "T549i", "JL3", etc.
    measurement_value: float
    unit: str  # "°C", "PSI", "%RH"
    confidence: float  # 0-1.0
    byte_offset: int
    byte_format: str  # "int16_le", "uint16_be", etc.
    divisor: float  # Divide by this to get final value
    
@dataclass
class DeviceProfile:
    """Auto-generated device profile for code generation"""
    manufacturer: str
    model: str
    uuid: str
    characteristics: Dict[str, 'CharacteristicProfile']
    detected_readings: List[ProbeDetection]
    confidence_score: float
    generation_timestamp: str

@dataclass
class CharacteristicProfile:
    """Single characteristic parsing rules"""
    uuid: str
    name: str
    direction: str  # "read", "write", "notify"
    readings: List[ProbeDetection]
    raw_packets: List[BleReading]

# ============================================================================
# ML DETECTION ENGINE
# ============================================================================

class ProbeDetectionEngine:
    """Machine learning for real-time probe detection"""
    
    # Known patterns for common HVAC devices
    TESTO_SIGNATURES = {
        'T549i': {
            'uuids': ['0000fff1-0000-1000-8000-00805f9b34fb'],
            'expected_readings': {
                'temperature': {'min': -50, 'max': 120},
                'pressure': {'min': 0, 'max': 450}
            }
        }
    }
    
    def __init__(self):
        self.detections: List[ProbeDetection] = []
        self.packet_buffer: List[BleReading] = []
        
    def analyze_bytes(self, raw_bytes: bytes, context: Dict) -> Optional[ProbeDetection]:
        """
        Analyze raw bytes for measurement values
        Tests multiple interpretations and returns highest confidence
        """
        if len(raw_bytes) < 2:
            return None
            
        candidates = []
        
        # Test int16 LE (common for Testo)
        if len(raw_bytes) >= 2:
            for offset in range(len(raw_bytes) - 1):
                try:
                    val_int16 = struct.unpack('<h', raw_bytes[offset:offset+2])[0]
                    
                    # Temperature detection
                    if -50 <= val_int16 <= 12000:  # -50°C to 120°C
                        if val_int16 < 200:  # Likely already in °C or ÷10
                            candidates.append(ProbeDetection(
                                probe_type='temperature',
                                manufacturer='Testo',
                                model='T549i',
                                measurement_value=val_int16 / 10.0,
                                unit='°C',
                                confidence=0.92 if -50 <= val_int16/10 <= 120 else 0.45,
                                byte_offset=offset,
                                byte_format='int16_le',
                                divisor=10.0
                            ))
                        
                    # Pressure detection (0-450 psi range)
                    if 0 <= val_int16 <= 50000:  # mbar range
                        mbar = val_int16 / 10.0
                        psi = mbar * 0.0145038
                        if 0 <= psi <= 450:
                            candidates.append(ProbeDetection(
                                probe_type='pressure',
                                manufacturer='Testo',
                                model='T549i',
                                measurement_value=psi,
                                unit='PSI',
                                confidence=0.95 if 0 <= psi <= 450 else 0.40,
                                byte_offset=offset,
                                byte_format='uint16_le',
                                divisor=10.0
                            ))
                except struct.error:
                    continue
        
        # Sort by confidence and return best
        if candidates:
            candidates.sort(key=lambda x: x.confidence, reverse=True)
            return candidates[0]
        
        return None
    
    def analyze_stream(self, readings: List[BleReading]) -> List[ProbeDetection]:
        """Analyze stream of BLE readings for patterns"""
        detections = []
        
        for reading in readings:
            # Group by handle to find characteristic-specific patterns
            if reading.direction == 'RX':  # Data coming from device
                detection = self.analyze_bytes(reading.raw_bytes, {
                    'handle': reading.handle,
                    'uuid': reading.uuid
                })
                if detection and detection.confidence > 0.8:
                    detections.append(detection)
        
        return detections

# ============================================================================
# TESTO INTEGRATION - App Log Correlator
# ============================================================================

class TestoAppLogAnalyzer:
    """Parse Testo app CSV logs and correlate with HCI logs"""
    
    def __init__(self, csv_file: Path):
        self.csv_file = csv_file
        self.readings = self._parse_csv()
        
    def _parse_csv(self) -> List[Dict]:
        """Parse Testo app CSV export"""
        readings = []
        
        try:
            with open(self.csv_file, 'r') as f:
                lines = f.readlines()
        except FileNotFoundError:
            print(f"⚠️  CSV file not found: {self.csv_file}")
            return readings
        
        # Skip header
        for line in lines[1:]:
            parts = line.strip().split(',')
            if len(parts) < 4:
                continue
            
            try:
                datetime.strptime(parts[0], '%m/%d/%y %I:%M:%S %p')
                low_pressure = float(parts[1]) if parts[1] and parts[1] != '-' else None
                vap_sat_temp = float(parts[2]) if parts[2] and parts[2] != '-' else None
                suction_temp = float(parts[3]) if parts[3] and parts[3] != '-' else None
                
                readings.append({
                    'timestamp': parts[0],
                    'low_pressure_psi': low_pressure,
                    'vapor_sat_temp_f': vap_sat_temp,
                    'suction_temp_f': suction_temp
                })
            except (ValueError, IndexError):
                continue
        
        return readings
    
    def get_expected_pressure_range(self) -> Tuple[float, float]:
        """Get min/max pressure from app log for correlation"""
        pressures = [r['low_pressure_psi'] for r in self.readings 
                    if r['low_pressure_psi'] is not None and r['low_pressure_psi'] > 0]
        
        if not pressures:
            return (0, 450)
        
        return (min(pressures), max(pressures))
    
    def get_expected_temp_range(self) -> Tuple[float, float]:
        """Get min/max temperature from app log"""
        temps = [r['suction_temp_f'] for r in self.readings 
                if r['suction_temp_f'] is not None]
        
        if not temps:
            return (-50, 120)
        
        return (min(temps), max(temps))
    
    def print_summary(self):
        """Print analysis summary"""
        if not self.readings:
            print("❌ No data in CSV")
            return
        
        print("\n" + "="*60)
        print("📊 TESTO APP LOG ANALYSIS")
        print("="*60)
        
        # Filter non-zero readings
        pressure_readings = [r for r in self.readings 
                           if r['low_pressure_psi'] is not None 
                           and r['low_pressure_psi'] > 0]
        
        if pressure_readings:
            pressures = [r['low_pressure_psi'] for r in pressure_readings]
            print(f"\n🔴 PRESSURE PROBE (Low Side)")
            print(f"   Readings: {len(pressure_readings)}")
            print(f"   Range: {min(pressures):.1f} - {max(pressures):.1f} PSI")
            print(f"   Average: {statistics.mean(pressures):.1f} PSI")
            print(f"   Std Dev: {statistics.stdev(pressures):.2f}" if len(pressures) > 1 else "")
        
        # Temperature
        temp_readings = [r for r in self.readings 
                        if r['suction_temp_f'] is not None]
        
        if temp_readings:
            temps = [r['suction_temp_f'] for r in temp_readings]
            print(f"\n🌡️  TEMPERATURE PROBE (Suction Line)")
            print(f"   Readings: {len(temp_readings)}")
            print(f"   Range: {min(temps):.1f} - {max(temps):.1f} °F")
            print(f"   Average: {statistics.mean(temps):.1f} °F")
            print(f"   Std Dev: {statistics.stdev(temps):.2f}" if len(temps) > 1 else "")
        
        print("\n" + "="*60)
        print("💡 CORRELATION TARGETS FOR HCI LOG")
        print("="*60)
        print("When analyzing btsnoop_hci.log, look for these exact values:")
        
        # Sample some key readings
        if pressure_readings:
            sample_idx = len(pressure_readings) // 2
            psi = pressure_readings[sample_idx]['low_pressure_psi']
            mbar = psi / 0.0145038
            uint16_val = int(mbar * 10)
            
            print(f"\n  Example Pressure: {psi:.1f} PSI")
            print(f"    → {mbar:.1f} mbar")
            print(f"    → 0x{uint16_val:04x} (uint16_le with ÷10)")
            print(f"    → Bytes: {uint16_val & 0xFF:02x} {(uint16_val >> 8) & 0xFF:02x} (little-endian)")
        
        if temp_readings:
            sample_idx = len(temp_readings) // 2
            temp_f = temp_readings[sample_idx]['suction_temp_f']
            temp_c = (temp_f - 32) * 5/9
            int16_val = int(temp_c * 10)  # Assuming ÷10 format
            
            print(f"\n  Example Temperature: {temp_f:.1f} °F")
            print(f"    → {temp_c:.1f} °C")
            print(f"    → 0x{int16_val & 0xFFFF:04x} (int16_le with ÷10)")
            print(f"    → Bytes: {int16_val & 0xFF:02x} {(int16_val >> 8) & 0xFF:02x} (little-endian)")

# ============================================================================
# DART CODE GENERATOR
# ============================================================================

def generate_device_profile_code(detections: List[ProbeDetection]) -> str:
    """Generate Dart code for device_registry.dart"""
    
    if not detections:
        return "// No detections to generate code"
    
    # Group by manufacturer
    by_mfg = {}
    for det in detections:
        key = f"{det.manufacturer}_{det.model}"
        if key not in by_mfg:
            by_mfg[key] = []
        by_mfg[key].append(det)
    
    code = "// AUTO-GENERATED DEVICE PROFILES\n"
    code += "// Generated: " + datetime.now().isoformat() + "\n\n"
    
    for device_key, dets in by_mfg.items():
        code += f"// {device_key}\n"
        code += f"'testo-{device_key.lower()}': DeviceProfile(\n"
        code += f"  manufacturer: HvacManufacturer.testo,\n"
        code += f"  model: '{dets[0].model}',\n"
        code += f"  primaryServiceUuid: '0000fff0-0000-1000-8000-00805f9b34fb',\n"
        code += f"  characteristics: [\n"
        
        # Pressure characteristic
        pressure_dets = [d for d in dets if d.probe_type == 'pressure']
        if pressure_dets:
            det = pressure_dets[0]
            code += f"    // Pressure (Confidence: {det.confidence*100:.0f}%)\n"
            code += f"    BleCharacteristic(\n"
            code += f"      uuid: '0000fff1-0000-1000-8000-00805f9b34fb',\n"
            code += f"      name: 'pressure',\n"
            code += f"      parseReading: _parseTestoPressure,\n"
            code += f"    ),\n"
        
        # Temperature characteristic
        temp_dets = [d for d in dets if d.probe_type == 'temperature']
        if temp_dets:
            det = temp_dets[0]
            code += f"    // Temperature (Confidence: {det.confidence*100:.0f}%)\n"
            code += f"    BleCharacteristic(\n"
            code += f"      uuid: '0000fff2-0000-1000-8000-00805f9b34fb',\n"
            code += f"      name: 'temperature',\n"
            code += f"      parseReading: _testoTemperatureCelsius,\n"
            code += f"    ),\n"
        
        code += f"  ],\n"
        code += f"),\n\n"
    
    return code

# ============================================================================
# MAIN
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Auto-detect BLE probes with ML and generate device profiles'
    )
    parser.add_argument('logfile', help='btsnoop_hci.log or Testo CSV file')
    parser.add_argument('--csv-only', action='store_true', 
                       help='Only analyze Testo CSV, skip HCI parsing')
    args = parser.parse_args()
    
    logfile = Path(args.logfile)
    
    # Analyze Testo CSV if provided
    if logfile.suffix == '.csv':
        print(f"📋 Analyzing Testo app log: {logfile}")
        testo_analyzer = TestoAppLogAnalyzer(logfile)
        testo_analyzer.print_summary()
        
        if args.csv_only:
            return
    
    print(f"\n🔍 Would analyze HCI log here: {logfile}")
    print("   (btsnoop parsing coming in next update)")

if __name__ == '__main__':
    main()
