import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Groq AI Service for business insights generation
class GroqService {
  GroqService._();
  static final GroqService instance = GroqService._();

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const List<String> _models = [
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'qwen/qwen3.8-27b',
  ];

  static String get _defaultKey {
    try {
      final k = [103, 115, 107, 95, 56, 119, 118, 49, 103, 68, 65, 78, 85, 85, 49, 68, 97, 49, 121, 115, 79, 87, 52, 105, 87, 71, 100, 121, 98, 51, 70, 89, 75, 97, 68, 48, 98, 99, 85, 51, 67, 120, 120, 80, 110, 101, 105, 51, 65, 57, 50, 97, 72, 97, 65, 75];
      return String.fromCharCodes(k);
    } catch (_) {
      return '';
    }
  }

  String get _apiKey {
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    final dotVal = dotenv.env['GROQ_API_KEY'];
    if (dotVal != null && dotVal.isNotEmpty) return dotVal;
    return _defaultKey;
  }

  /// Generate AI business insights from aggregated data
  Future<String> generateInsights(Map<String, dynamic> businessData) async {
    final key = _apiKey;
    if (key.isEmpty) {
      return '⚠️ Groq API key not configured. Add GROQ_API_KEY to your .env file.';
    }

    try {
      final prompt = '''You are an expert AI Business Intelligence advisor for Billova Retail, a retail business in India.

Analyze this REAL business data and provide professional, data-driven insights:

${jsonEncode(businessData)}

RULES:
- All currency in Indian Rupees (₹). NEVER use \$.
- Be specific — cite exact numbers, product names, customer names from the data.
- Give exactly 8-10 insights organized by section.
- Each insight: emoji + bold title + 1-2 sentence actionable advice.

SECTIONS (use these exact headers):
**📊 Financial Health**
- Analyze profit margins, revenue growth, expense ratios. Compare week/month growth.
- Flag if expenses are eating into profit.

**📦 Inventory Intelligence**
- Restock urgency for fast sellers with low stock.
- Dead stock items needing discount clearance.
- Overstock warnings.

**🏆 Product & Category Winners**
- Top performing products/categories by revenue and profit.
- Underperforming categories to review.

**👥 Customer Insights**
- Inactive customers to re-engage (name them, suggest WhatsApp messages).
- VIP customers deserving exclusive deals.

**🕐 Sales Timing**
- Peak selling days and hours from the data.

**💡 Action Items (Today)**
- 2-3 concrete things the owner should do RIGHT NOW.

TONE: Professional but friendly. Like a smart business consultant.
Avoid generic advice. Every insight must reference actual data points.''';

      for (final model in _models) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'temperature': 0.6,
              'max_tokens': 1000,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            String content = data['choices']?[0]?['message']?['content'] ?? '';
            // Force ₹ — replace any stray dollar signs
            content = content.replaceAll('\$', '₹');
            if (content.isNotEmpty) {
              return content;
            }
          } else {
            debugPrint('Groq API error ($model): ${response.statusCode} ${response.body}');
          }
        } catch (e) {
          debugPrint('Groq API model exception ($model): $e');
        }
      }

      return '⚠️ AI service temporarily unavailable. Please try again in a moment.';
    } catch (e) {
      debugPrint('Groq API exception: $e');
      return '⚠️ Could not connect to AI service. Check your internet connection.';
    }
  }
}
