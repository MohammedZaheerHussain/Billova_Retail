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
      final prompt = '''You are a smart and friendly retail business assistant for a shoe/clothing shop called SKYWALK in India.

Analyze the following business data and give helpful, practical suggestions.

Business Data:
${jsonEncode(businessData)}

Rules:
- All currency values are in Indian Rupees (₹). ALWAYS use ₹ symbol, NEVER use dollars or \$.
- Keep tone friendly and conversational — talk like a helpful business partner, not a robot
- Give exactly 6-8 short, actionable bullet points
- Start each point with a relevant emoji (💡 ✅ ⚠️ 📦 💰 📈 🔥 👍 🎯 📱 👥)
- Keep each point to 1-2 sentences max
- Be specific with numbers from the data
- Suggest concrete actions the owner can take today

Focus on:
1. 📈 Sales insights (trends, wins, concerns)
2. 📦 Inventory suggestions (restock, slow movers)
3. 💰 Profit improvement tips
4. ⚠️ Risks or warnings
5. 💡 Quick opportunities
6. 👥 Customer retention — identify inactive customers and suggest WhatsApp offers to bring them back
7. 🎯 VIP customers — highlight top spenders and suggest exclusive deals for them
8. 📱 WhatsApp marketing — suggest specific offers or messages to send based on current stock and customer behavior

If there are inactive customers (haven't bought in 7+ days), suggest sending them a WhatsApp offer.
If there are high-spending customers, suggest VIP treatment or loyalty rewards.
Always include at least 1 customer engagement suggestion.

Example tone:
"👍 Your sales are looking solid this week — keep it up!"
"📦 You might want to restock those fast-moving items soon"
"💡 Try running a small discount on slow movers to clear stock"
"⚠️ Expenses are creeping up — worth reviewing today"
"📱 3 customers haven't visited in 10+ days — send them a WhatsApp offer!"
"🎯 Rahul has spent ₹15K — consider a VIP discount to keep him loyal"

Avoid technical jargon. Be brief and human.''';

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
          'temperature': 0.7,
          'max_tokens': 600,
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
