import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Gemini Chat Service - Admin-configurable AI assistant
/// Serves as a fallback when TekMate is unavailable
/// Can be enabled/disabled via admin settings
class GeminiChatService {
  static final GeminiChatService _instance = GeminiChatService._internal();

  factory GeminiChatService() {
    return _instance;
  }

  GeminiChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GenerativeModel? _model;
  bool _isInitialized = false;
  bool _isEnabled = false;
  bool _isAdmin = false;
  String _personality = _defaultPersonality;

  static const String _defaultPersonality = 
      'You are a helpful HVAC technical support assistant. '
      'You provide clear, professional guidance to HVAC technicians and homeowners. '
      'Be concise, practical, and safety-conscious in your responses. '
      'When providing troubleshooting advice, explain the reasoning behind your recommendations.';

  /// Initialize service - checks admin status and loads configuration
  Future<bool> init() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _isAdmin = false;
        _isInitialized = true;
        return false;
      }

      // Check admin status
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      _isAdmin = (userData['role'] == 'admin') || (userData['isAdmin'] == true);

      // Load Gemini settings from Firestore
      final settingsDoc = await _firestore
          .collection('settings')
          .doc('gemini')
          .get();

      if (settingsDoc.exists) {
        final settings = settingsDoc.data()!;
        _isEnabled = settings['enabled'] ?? false;
        _personality = settings['personality'] ?? _defaultPersonality;

        final apiKey = settings['apiKey'] as String?;
        
        if (apiKey != null && apiKey.isNotEmpty && _isEnabled) {
          _model = GenerativeModel(
            model: 'gemini-1.5-flash',
            apiKey: apiKey,
            systemInstruction: Content.system(_personality),
          );
          debugPrint('Gemini service initialized with API key');
        } else {
          debugPrint('Gemini API key not configured or service disabled');
        }
      } else {
        debugPrint('Gemini settings not found in Firestore');
      }

      _isInitialized = true;
      return _isEnabled && _model != null;
    } catch (e) {
      debugPrint('Gemini initialization error: $e');
      _isInitialized = true;
      return false;
    }
  }

  /// Get AI response for a message
  /// Returns null if service is not available or disabled
  Future<GeminiResponse?> getResponse(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    if (!_isEnabled || _model == null) {
      return null;
    }

    try {
      // Build enhanced prompt with context
      String enhancedPrompt = message;
      
      if (context != null && context.isNotEmpty) {
        enhancedPrompt = _buildContextualPrompt(message, context);
      }

      final content = [Content.text(enhancedPrompt)];
      final response = await _model!.generateContent(content);

      final responseText = response.text ?? '';
      
      // Estimate confidence based on response characteristics
      final confidence = _estimateConfidence(responseText);

      return GeminiResponse(
        response: responseText,
        confidence: confidence,
        autoRespond: confidence > 0.85,
      );
    } catch (e) {
      debugPrint('Gemini API error: $e');
      return null;
    }
  }

  /// Build contextual prompt with conversation history and metadata
  String _buildContextualPrompt(String message, Map<String, dynamic> context) {
    final buffer = StringBuffer();
    
    // Add context information
    if (context['systemType'] != null) {
      buffer.writeln('System Type: ${context['systemType']}');
    }
    if (context['refrigerant'] != null) {
      buffer.writeln('Refrigerant: ${context['refrigerant']}');
    }
    
    // Add recent conversation history
    if (context['recentMessages'] != null) {
      final messages = context['recentMessages'] as List;
      if (messages.isNotEmpty) {
        buffer.writeln('\nRecent Conversation:');
        for (final msg in messages.take(5)) {
          final sender = msg['senderType'] ?? 'unknown';
          final text = msg['text'] ?? '';
          buffer.writeln('$sender: $text');
        }
        buffer.writeln();
      }
    }
    
    buffer.writeln('Current Question: $message');
    
    return buffer.toString();
  }

  /// Estimate confidence score based on response characteristics
  double _estimateConfidence(String response) {
    // Simple heuristic: longer, more detailed responses = higher confidence
    // Presence of numbers, measurements, specific terms = higher confidence
    
    double score = 0.7; // Base confidence
    
    // Increase for length (indicates detailed response)
    if (response.length > 200) score += 0.05;
    if (response.length > 500) score += 0.05;
    
    // Increase for technical terms
    final technicalTerms = [
      'pressure', 'refrigerant', 'superheat', 'subcool',
      'compressor', 'condenser', 'evaporator', 'PSI',
      'temperature', 'airflow'
    ];
    
    final lowerResponse = response.toLowerCase();
    int termCount = 0;
    for (final term in technicalTerms) {
      if (lowerResponse.contains(term)) termCount++;
    }
    score += (termCount * 0.02).clamp(0.0, 0.1);
    
    // Decrease if response contains uncertainty phrases
    final uncertaintyPhrases = [
      'i\'m not sure', 'might be', 'could be', 'possibly',
      'i don\'t know', 'uncertain'
    ];
    
    for (final phrase in uncertaintyPhrases) {
      if (lowerResponse.contains(phrase)) {
        score -= 0.15;
        break;
      }
    }
    
    // Cap at 95% - AI should never claim 100% certainty
    const maxConfidence = 0.95;
    return score.clamp(0.0, maxConfidence);
  }

  /// Check if Gemini is available and enabled
  bool get isAvailable => _isEnabled && _model != null;

  /// Check if user is admin
  bool get isAdmin => _isAdmin;

  /// Get current personality setting
  String get personality => _personality;

  /// Get default personality for reference
  static String get defaultPersonality => _defaultPersonality;

  /// Update personality setting (admin only)
  Future<bool> updatePersonality(String newPersonality) async {
    if (!_isAdmin) return false;

    try {
      await _firestore.collection('settings').doc('gemini').set({
        'personality': newPersonality,
      }, SetOptions(merge: true));

      _personality = newPersonality;
      
      // Reload model with new personality
      await init();
      
      return true;
    } catch (e) {
      debugPrint('Error updating personality: $e');
      return false;
    }
  }

  /// Enable or disable Gemini service (admin only)
  Future<bool> setEnabled(bool enabled) async {
    if (!_isAdmin) return false;

    try {
      await _firestore.collection('settings').doc('gemini').set({
        'enabled': enabled,
      }, SetOptions(merge: true));

      _isEnabled = enabled;
      
      return true;
    } catch (e) {
      debugPrint('Error updating enabled status: $e');
      return false;
    }
  }
}

/// Response model for Gemini chat
class GeminiResponse {
  final String response;
  final double confidence;
  final bool autoRespond;

  GeminiResponse({
    required this.response,
    required this.confidence,
    required this.autoRespond,
  });

  /// Whether response is high-confidence enough to use
  bool get isHighConfidence => confidence > 0.75;

  /// Whether response should be sent without human review
  bool get shouldAutoRespond => confidence > 0.85;

  /// Confidence as percentage (0-100)
  int get confidencePercent => (confidence * 100).toInt();
}
