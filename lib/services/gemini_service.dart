import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/account_model.dart';
import 'voice_input_service.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  final String apiKey;
  GeminiService(this.apiKey);

  Future<VoiceParseResult> parseVoiceInput(
      String input, List<AccountModel> accounts) async {
    final accountList = accounts
        .map((a) => '{"id":"${a.id}","name":"${a.name}","type":"${a.type}"}')
        .join(',');

    final prompt = '''
You are a financial transaction parser for an Indian money manager app.
Parse this voice input into a transaction and respond ONLY with valid JSON.

Voice input: "$input"

Available accounts: [$accountList]

Respond with ONLY this JSON (no explanation, no markdown):
{
  "amount": <number or null>,
  "type": "<income|expense|transfer>",
  "category": "<one of: Food & Dining, Transportation, Bills & Utilities, Healthcare, Shopping, Entertainment, Education, Personal Care, Travel, Salary, Business, Freelance, Investments, Gifts, Rental Income, Other, or null>",
  "subcategory": "<specific subcategory or null>",
  "fromAccountId": "<account id from list or null>",
  "toAccountId": "<account id from list or null, only for transfer>",
  "note": "<short clean note or null>",
  "confidence": <0.0 to 1.0>
}

Rules:
- For expense: fromAccountId = the account money comes OUT of
- For income: fromAccountId = the account money goes INTO  
- Match account by name similarity (SBI CC = SBI Credit Card, etc.)
- Indian keywords: petrol=Transportation/Fuel, bhai=person, chai=Food
- If type unclear from context, default to expense
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 300,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text']
            as String;

        // Clean response - remove markdown if present
        final clean = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final parsed = jsonDecode(clean) as Map<String, dynamic>;

        // Find account id
        String? fromAccountId = parsed['fromAccountId'];
        String? toAccountId = parsed['toAccountId'];

        return VoiceParseResult(
          amount: (parsed['amount'] as num?)?.toDouble(),
          type: parsed['type'] as String?,
          category: parsed['category'] as String?,
          subcategory: parsed['subcategory'] as String?,
          fromAccount: fromAccountId,
          toAccount: toAccountId,
          note: parsed['note'] as String?,
          date: DateTime.now(),
          confidence: (parsed['confidence'] as num?)?.toDouble() ?? 0.5,
        );
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to local parser if Gemini fails
      return VoiceInputService().parse(input, accounts);
    }
  }
}
