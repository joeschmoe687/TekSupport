// Export Q&A pairs from PocketBase as JSONL
// Make sure to replace YOUR_SERVER and YOUR_ADMIN_TOKEN

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

const String pocketBaseUrl =
    'https://api.airpronwa.com/api/collections/messages/records';

const String adminToken = 'YOUR_ADMIN_TOKEN';

Future<void> main() async {
  try {
    final response = await http.get(
      Uri.parse(pocketBaseUrl),
      headers: {'Authorization': 'Admin $adminToken'},
    );

    if (response.statusCode != 200) {
      print(
        '❌ Failed to fetch records: ${response.statusCode} - ${response.body}',
      );
      return;
    }

    final data = jsonDecode(response.body);
    final List records = data['items'] ?? [];

    if (records.isEmpty) {
      print('⚠️ No records found in qa_pairs collection.');
      return;
    }

    final file = File('qa_pairs_export.jsonl');
    final sink = file.openWrite();

    for (final record in records) {
      final prompt = record['question'] ?? '';
      final completion = record['answer'] ?? '';
      sink.writeln(jsonEncode({'prompt': prompt, 'completion': completion}));
    }

    await sink.flush();
    await sink.close();

    print('✅ Exported ${records.length} Q&A pairs to qa_pairs_export.jsonl');
  } catch (e) {
    print('❗ Error during export: $e');
  }
}
