import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// All OpenAI-related code lives in this file (Dreamflow requirement).
class OpenAIConfig {
  static const apiKey = String.fromEnvironment('OPENAI_PROXY_API_KEY');
  static const endpoint = String.fromEnvironment('OPENAI_PROXY_ENDPOINT');
}

class OpenAIExpenseExtraction {
  final double? amount;
  final String? category;
  final String? note;
  final DateTime? date;
  final String? accountType;

  const OpenAIExpenseExtraction({required this.amount, required this.category, required this.note, required this.date, required this.accountType});

  bool get isUsable => (amount != null && amount! > 0) && (category != null && category!.trim().isNotEmpty);

  static OpenAIExpenseExtraction empty() => const OpenAIExpenseExtraction(amount: null, category: null, note: null, date: null, accountType: null);
}

class OpenAIExpenseNlpService {
  static const List<String> allowedCategories = ['Food', 'Snacks', 'Travel', 'Bills', 'Shopping', 'Fun', 'Health'];

  Future<OpenAIExpenseExtraction> extractExpense({required String utterance, required DateTime nowLocal}) async {
    final trimmed = utterance.trim();
    if (trimmed.isEmpty) return OpenAIExpenseExtraction.empty();

    if (OpenAIConfig.apiKey.isEmpty || OpenAIConfig.endpoint.isEmpty) {
      debugPrint('OpenAI config missing: endpoint/apiKey not provided via environment variables.');
      throw StateError('AI parsing is not configured.');
    }

    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayIso = _toIsoDate(today);

    final system = '''You are an expense parsing assistant for an Indian personal finance app.
Return ONLY a valid JSON object (no markdown) matching this exact schema:
{
  "amount": number | null,
  "category": string | null,
  "note": string | null,
  "date": string | null,
  "accountType": "personal" | "business" | null
}
Rules:
- amount is in INR rupees. Extract numbers even if user says "rs", "rupaye", "rupees", "₹".
- category must be one of: Food, Snacks, Travel, Bills, Shopping, Fun, Health.
  - If user says snacks/chai/coffee/tea/paneer/khana/food: prefer Food or Snacks.
  - If unclear, pick the closest match.
- accountType: If the user mentions personal/business in English or Hinglish/Hindi (e.g., "personal", "personal me", "mera", "business", "biz", "office", "company", "ke liye"), set it. Otherwise null.
- note should be the remaining meaningful description (<= 60 chars), with filler words removed if possible.
- date must be an ISO date string "YYYY-MM-DD" in the user's local time. If user doesn't specify a date, use null.
- If user says "today" use $todayIso. If "yesterday" use the day before $todayIso. If "tomorrow" use the day after $todayIso.
''';

    final user = '''Today is $todayIso.
User said: "$trimmed"''';

    final payload = <String, dynamic>{
      'model': 'gpt-4o-mini',
      'temperature': 0.0,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };

    final uri = Uri.parse(OpenAIConfig.endpoint);

    http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${OpenAIConfig.apiKey}',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      debugPrint('OpenAI request failed: $e');
      debugPrint('$st');
      rethrow;
    }

    final decodedBody = utf8.decode(res.bodyBytes);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('OpenAI error: status=${res.statusCode} body=$decodedBody');
      throw StateError('AI parsing failed (${res.statusCode}).');
    }

    dynamic outer;
    try {
      outer = jsonDecode(decodedBody);
    } catch (e) {
      debugPrint('Failed to decode OpenAI outer JSON: $e body=$decodedBody');
      throw StateError('AI response was not valid JSON.');
    }

    final content = (outer is Map &&
            outer['choices'] is List &&
            (outer['choices'] as List).isNotEmpty &&
            (outer['choices'][0] as Map?)?['message'] is Map &&
            ((outer['choices'][0] as Map)['message'] as Map)['content'] is String)
        ? (((outer['choices'][0] as Map)['message'] as Map)['content'] as String)
        : null;

    if (content == null || content.trim().isEmpty) {
      debugPrint('OpenAI response missing content: $decodedBody');
      throw StateError('AI response was empty.');
    }

    dynamic inner;
    try {
      inner = jsonDecode(content);
    } catch (e) {
      debugPrint('Failed to decode OpenAI inner JSON: $e content=$content');
      throw StateError('AI returned malformed JSON.');
    }

    if (inner is! Map<String, dynamic>) return OpenAIExpenseExtraction.empty();

    final amountRaw = inner['amount'];
    final amount = amountRaw is num ? amountRaw.toDouble() : double.tryParse('${amountRaw ?? ''}');

    final categoryRaw = (inner['category'] as String?)?.trim();
    final category = _normalizeCategory(categoryRaw);

    final note = (inner['note'] as String?)?.trim();
    final dateIso = (inner['date'] as String?)?.trim();
    final date = _parseIsoDate(dateIso);

    final accountTypeRaw = (inner['accountType'] as String?)?.trim();
    final accountType = _normalizeAccountType(accountTypeRaw);

    return OpenAIExpenseExtraction(
      amount: (amount != null && amount.isFinite) ? amount : null,
      category: category,
      note: (note == null || note.isEmpty) ? null : (note.length > 60 ? note.substring(0, 60) : note),
      date: date,
      accountType: accountType,
    );
  }

  static String? _normalizeCategory(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    for (final c in allowedCategories) {
      if (c.toLowerCase() == lower) return c;
    }

    if (lower.contains('snack') || lower.contains('chai') || lower.contains('tea') || lower.contains('coffee')) return 'Snacks';
    if (lower.contains('food') || lower.contains('khana') || lower.contains('eat') || lower.contains('paneer')) return 'Food';
    if (lower.contains('trip') || lower.contains('cab') || lower.contains('travel') || lower.contains('uber')) return 'Travel';
    if (lower.contains('bill') || lower.contains('electric') || lower.contains('recharge') || lower.contains('rent')) return 'Bills';
    if (lower.contains('shop') || lower.contains('amazon') || lower.contains('flipkart')) return 'Shopping';
    if (lower.contains('movie') || lower.contains('fun') || lower.contains('party')) return 'Fun';
    if (lower.contains('doctor') || lower.contains('medicine') || lower.contains('health')) return 'Health';

    return null;
  }

  static String? _normalizeAccountType(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('business') || lower.contains('biz') || lower.contains('office') || lower.contains('company')) return 'business';
    if (lower.contains('personal') || lower.contains('mera') || lower.contains('my')) return 'personal';
    return null;
  }

  static DateTime? _parseIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static String _toIsoDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
