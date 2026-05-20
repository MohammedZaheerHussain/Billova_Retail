import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Groq AI Service for business insights generation
class GroqService {
  GroqService._();
  static final GroqService instance = GroqService._();

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';

  /// Generate AI business insights from aggregated data
  Future<String> generateInsights(Map<String, dynamic> businessData) async {
    if (_apiKey.isEmpty) {
      return '⚠️ Groq API key not configured. Add GROQ_API_KEY to your .env file.';
    }

    try {
      final prompt = '''You are an expert AI Business Intelligence advisor for SKYWALK, a retail shoe/clothing shop in India.

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

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
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
        return content;
      } else {
        debugPrint('Groq API error: ${response.statusCode} ${response.body}');
        return '⚠️ AI service temporarily unavailable. Status: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Groq API exception: $e');
      return '⚠️ Could not connect to AI service. Check your internet connection.';
    }
  }
}
