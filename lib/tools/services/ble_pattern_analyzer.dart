import 'dart:typed_data';
import 'dart:math' as math;

/// Advanced pattern analysis for BLE data streams
/// Detects common HVAC sensor data formats automatically
class BlePatternAnalyzer {
  /// Analyze a data stream and suggest parsing methods
  static DataInterpretation analyzeDataStream(List<List<int>> packets) {
    if (packets.isEmpty) {
      return DataInterpretation(
        confidence: 0.0,
        suggestions: [],
        detectedFormat: 'unknown',
      );
    }

    final suggestions = <ParseSuggestion>[];
    
    // Analyze each packet to find patterns
    for (final packet in packets) {
      if (packet.isEmpty) continue;
      
      // Try all common interpretations
      suggestions.addAll(_analyzePacket(packet));
    }
    
    // Group and score suggestions
    final grouped = _groupSuggestions(suggestions);
    final scored = _scoreSuggestions(grouped, packets.length);
    
    return DataInterpretation(
      confidence: scored.isNotEmpty ? scored.first.confidence : 0.0,
      suggestions: scored.take(5).toList(),
      detectedFormat: scored.isNotEmpty ? scored.first.formatName : 'unknown',
    );
  }

  /// Analyze a single packet for all possible interpretations
  static List<ParseSuggestion> _analyzePacket(List<int> packet) {
    final suggestions = <ParseSuggestion>[];
    
    if (packet.length < 2) return suggestions;
    
    final bytes = Uint8List.fromList(packet);
    final byteData = ByteData.view(bytes.buffer);
    
    // Try different byte positions and formats
    for (int offset = 0; offset <= packet.length - 2; offset++) {
      // Int16 Little Endian
      if (offset + 2 <= packet.length) {
        final int16LE = byteData.getInt16(offset, Endian.little);
        final uint16LE = byteData.getUint16(offset, Endian.little);
        
        // Common HVAC scaling factors
        for (final divisor in [1.0, 10.0, 100.0, 1000.0]) {
          final value = int16LE / divisor;
          final category = _categorizeValue(value);
          if (category != null) {
            suggestions.add(ParseSuggestion(
              offset: offset,
              length: 2,
              formatName: 'int16_le_div${divisor.toInt()}',
              value: value,
              category: category,
              confidence: _calculateConfidence(value, category),
              endianness: 'little',
              signed: true,
              divisor: divisor,
            ));
          }
          
          // Also try unsigned
          final uvalue = uint16LE / divisor;
          final ucategory = _categorizeValue(uvalue);
          if (ucategory != null) {
            suggestions.add(ParseSuggestion(
              offset: offset,
              length: 2,
              formatName: 'uint16_le_div${divisor.toInt()}',
              value: uvalue,
              category: ucategory,
              confidence: _calculateConfidence(uvalue, ucategory),
              endianness: 'little',
              signed: false,
              divisor: divisor,
            ));
          }
        }
        
        // Int16 Big Endian
        final int16BE = byteData.getInt16(offset, Endian.big);
        for (final divisor in [1.0, 10.0, 100.0, 1000.0]) {
          final value = int16BE / divisor;
          final category = _categorizeValue(value);
          if (category != null) {
            suggestions.add(ParseSuggestion(
              offset: offset,
              length: 2,
              formatName: 'int16_be_div${divisor.toInt()}',
              value: value,
              category: category,
              confidence: _calculateConfidence(value, category),
              endianness: 'big',
              signed: true,
              divisor: divisor,
            ));
          }
        }
      }
      
      // Float32 Little Endian
      if (offset + 4 <= packet.length) {
        try {
          final float32LE = byteData.getFloat32(offset, Endian.little);
          if (float32LE.isFinite) {
            final category = _categorizeValue(float32LE);
            if (category != null) {
              suggestions.add(ParseSuggestion(
                offset: offset,
                length: 4,
                formatName: 'float32_le',
                value: float32LE,
                category: category,
                confidence: _calculateConfidence(float32LE, category),
                endianness: 'little',
                signed: true,
                divisor: 1.0,
              ));
            }
          }
        } catch (_) {}
      }
    }
    
    return suggestions;
  }

  /// Categorize a numeric value into likely sensor types
  static String? _categorizeValue(double value) {
    // Temperature ranges
    if (value >= -50 && value <= 50) return 'temperature_celsius';
    if (value >= -58 && value <= 122) return 'temperature_fahrenheit';
    if (value >= 32 && value <= 212) return 'temperature_fahrenheit_water';
    
    // Pressure ranges
    if (value >= -30 && value <= 800) return 'pressure_psig';
    if (value >= 0 && value <= 5000) return 'pressure_mbar';
    if (value >= -30 && value <= 60) return 'pressure_inhg';
    
    // Humidity
    if (value >= 0 && value <= 100) return 'humidity_percent';
    
    // Airflow
    if (value >= 0 && value <= 10000) return 'airflow_fpm';
    if (value >= 0 && value <= 5000) return 'airflow_cfm';
    
    // Weight
    if (value >= 0 && value <= 1000) return 'weight_lbs_or_oz';
    if (value >= 0 && value <= 500) return 'weight_kg';
    
    // Electrical
    if (value >= 0 && value <= 600) return 'current_amps';
    if (value >= 0 && value <= 1000) return 'voltage_volts';
    
    // Battery
    if (value >= 0 && value <= 100 && value == value.round()) {
      return 'battery_percent';
    }
    
    return null; // Value doesn't fit typical HVAC ranges
  }

  /// Calculate confidence score for a value/category pair
  static double _calculateConfidence(double value, String category) {
    // Higher confidence for values in the "sweet spot" of each range
    switch (category) {
      case 'temperature_celsius':
        return _gaussianConfidence(value, 20.0, 15.0);
      case 'temperature_fahrenheit':
        return _gaussianConfidence(value, 70.0, 40.0);
      case 'pressure_psig':
        return _gaussianConfidence(value, 100.0, 200.0);
      case 'humidity_percent':
        return _gaussianConfidence(value, 50.0, 30.0);
      case 'airflow_fpm':
        return _gaussianConfidence(value, 400.0, 1000.0);
      case 'current_amps':
        return _gaussianConfidence(value, 20.0, 50.0);
      default:
        return 0.5; // Medium confidence
    }
  }

  /// Gaussian confidence distribution
  static double _gaussianConfidence(double value, double mean, double stdDev) {
    final exponent = -math.pow((value - mean) / stdDev, 2) / 2;
    return 0.3 + 0.7 * math.exp(exponent); // Range: 0.3 to 1.0
  }

  /// Group similar suggestions
  static Map<String, List<ParseSuggestion>> _groupSuggestions(
      List<ParseSuggestion> suggestions) {
    final grouped = <String, List<ParseSuggestion>>{};
    
    for (final suggestion in suggestions) {
      final key = '${suggestion.offset}_${suggestion.formatName}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(suggestion);
    }
    
    return grouped;
  }

  /// Score and rank suggestions by consistency across packets
  static List<ParseSuggestion> _scoreSuggestions(
      Map<String, List<ParseSuggestion>> grouped, int totalPackets) {
    final scored = <ParseSuggestion>[];
    
    for (final entry in grouped.entries) {
      final suggestions = entry.value;
      if (suggestions.isEmpty) continue;
      
      // Calculate consistency score
      final consistency = suggestions.length / totalPackets;
      
      // Calculate average confidence
      final avgConfidence = suggestions
          .map((s) => s.confidence)
          .reduce((a, b) => a + b) / suggestions.length;
      
      // Calculate value stability (low variance = stable reading)
      final values = suggestions.map((s) => s.value).toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values
          .map((v) => math.pow(v - mean, 2))
          .reduce((a, b) => a + b) / values.length;
      final stability = 1.0 / (1.0 + variance);
      
      // Combined score
      final finalConfidence = (avgConfidence * 0.4) + 
                              (consistency * 0.3) + 
                              (stability * 0.3);
      
      scored.add(ParseSuggestion(
        offset: suggestions.first.offset,
        length: suggestions.first.length,
        formatName: suggestions.first.formatName,
        value: mean, // Use average value
        category: suggestions.first.category,
        confidence: finalConfidence,
        endianness: suggestions.first.endianness,
        signed: suggestions.first.signed,
        divisor: suggestions.first.divisor,
        sampleCount: suggestions.length,
      ));
    }
    
    // Sort by confidence descending
    scored.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    return scored;
  }

  /// Detect if data is likely CRC/checksum protected
  static ChecksumInfo? detectChecksum(List<int> packet) {
    if (packet.length < 3) return null;
    
    // Common checksum patterns
    // XOR checksum (common in HVAC devices)
    int xorSum = 0;
    for (int i = 0; i < packet.length - 1; i++) {
      xorSum ^= packet[i];
    }
    if (xorSum == packet.last) {
      return ChecksumInfo(
        type: 'XOR',
        position: packet.length - 1,
        confidence: 0.9,
      );
    }
    
    // Sum checksum (byte sum modulo 256)
    int byteSum = 0;
    for (int i = 0; i < packet.length - 1; i++) {
      byteSum = (byteSum + packet[i]) & 0xFF;
    }
    if (byteSum == packet.last) {
      return ChecksumInfo(
        type: 'SUM_MOD256',
        position: packet.length - 1,
        confidence: 0.9,
      );
    }
    
    // 2's complement checksum
    final twosComp = ((~byteSum) + 1) & 0xFF;
    if (twosComp == packet.last) {
      return ChecksumInfo(
        type: 'TWOS_COMPLEMENT',
        position: packet.length - 1,
        confidence: 0.9,
      );
    }
    
    return null;
  }

  /// Analyze packet timing to detect update rate
  static TimingInfo analyzeTiminginfo(List<DateTime> timestamps) {
    if (timestamps.length < 3) {
      return TimingInfo(
        averageInterval: Duration.zero,
        jitter: 0.0,
        frequency: 0.0,
      );
    }
    
    final intervals = <Duration>[];
    for (int i = 1; i < timestamps.length; i++) {
      intervals.add(timestamps[i].difference(timestamps[i - 1]));
    }
    
    final avgMs = intervals
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b) / intervals.length;
    
    final variance = intervals
        .map((d) => math.pow(d.inMilliseconds - avgMs, 2))
        .reduce((a, b) => a + b) / intervals.length;
    
    return TimingInfo(
      averageInterval: Duration(milliseconds: avgMs.round()),
      jitter: math.sqrt(variance),
      frequency: avgMs > 0 ? 1000.0 / avgMs : 0.0,
    );
  }
}

/// Suggested parse method for a data field
class ParseSuggestion {
  final int offset;
  final int length;
  final String formatName;
  final double value;
  final String category;
  final double confidence;
  final String endianness;
  final bool signed;
  final double divisor;
  final int sampleCount;

  ParseSuggestion({
    required this.offset,
    required this.length,
    required this.formatName,
    required this.value,
    required this.category,
    required this.confidence,
    required this.endianness,
    required this.signed,
    required this.divisor,
    this.sampleCount = 1,
  });

  String get humanReadable {
    final sign = signed ? 'int' : 'uint';
    final bytes = length * 8;
    final div = divisor != 1.0 ? ' ÷ ${divisor.toInt()}' : '';
    return 'Bytes [$offset-${offset + length - 1}]: $sign$bytes ${endianness.toUpperCase()}$div';
  }

  String get categoryDisplay {
    return category
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  /// Generate Dart parsing code
  String generateDartCode(String functionName) {
    final bytesExpr = 'Uint8List.fromList(rawData.sublist($offset, ${offset + length}))';
    final endian = endianness == 'little' ? 'Endian.little' : 'Endian.big';
    final method = signed ? 'getInt$length' : 'getUint${length * 8}';
    
    if (length == 4 && formatName.contains('float')) {
      return '''
double $functionName(List<int> rawData) {
  if (rawData.length < ${offset + length}) return double.nan;
  final bytes = $bytesExpr;
  final byteData = ByteData.view(bytes.buffer);
  return byteData.getFloat32(0, $endian);
}''';
    } else {
      final divExpr = divisor != 1.0 ? ' / $divisor' : '';
      return '''
double $functionName(List<int> rawData) {
  if (rawData.length < ${offset + length}) return double.nan;
  final bytes = $bytesExpr;
  final byteData = ByteData.view(bytes.buffer);
  return byteData.$method(0, $endian)$divExpr;
}''';
    }
  }
}

/// Result of data interpretation analysis
class DataInterpretation {
  final double confidence;
  final List<ParseSuggestion> suggestions;
  final String detectedFormat;

  DataInterpretation({
    required this.confidence,
    required this.suggestions,
    required this.detectedFormat,
  });
}

/// Checksum detection result
class ChecksumInfo {
  final String type;
  final int position;
  final double confidence;

  ChecksumInfo({
    required this.type,
    required this.position,
    required this.confidence,
  });
}

/// Packet timing analysis result
class TimingInfo {
  final Duration averageInterval;
  final double jitter;
  final double frequency;

  TimingInfo({
    required this.averageInterval,
    required this.jitter,
    required this.frequency,
  });

  String get humanReadable {
    if (frequency == 0) return 'No data';
    return '${frequency.toStringAsFixed(1)} Hz (${averageInterval.inMilliseconds} ms ± ${jitter.toStringAsFixed(1)} ms)';
  }
}
