import 'dart:convert';
import 'package:http/http.dart' as http;
import 'internet_audio.dart';

class CommonsAudioSearch {
  final http.Client client;
  CommonsAudioSearch(this.client);

  Future<List<OnlineSound>> search(String phrase) async {
    final uri = Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': 'filetype:audio $phrase',
      'gsrnamespace': '6',
      'gsrlimit': '20',
      'prop': 'imageinfo',
      'iiprop': 'url|extmetadata|mime',
      'format': 'json',
      'formatversion': '2',
    });
    final response = await client.get(uri, headers: {
      'User-Agent': 'WhatSound/0.1 (RoboTop Studios; audio search prototype)',
    }).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final query = data['query'] as Map<String, dynamic>? ?? {};
    final pages = query['pages'] as List<dynamic>? ?? [];
    final found = <OnlineSound>[];
    for (final item in pages) {
      final page = item as Map<String, dynamic>;
      final info = page['imageinfo'] as List<dynamic>? ?? [];
      if (info.isEmpty) continue;
      final file = info.first as Map<String, dynamic>;
      final mime = (file['mime'] ?? '').toString();
      final url = (file['url'] ?? '').toString();
      if (!mime.startsWith('audio/') || url.isEmpty) continue;
      final metadata = file['extmetadata'] as Map<String, dynamic>? ?? {};
      final license = (metadata['LicenseShortName'] as Map<String, dynamic>?)?['value']?.toString() ?? '';
      found.add(OnlineSound(
        title: (page['title'] ?? 'Audio').toString().replaceFirst('File:', ''),
        url: url,
        source: 'Wikimedia Commons',
        license: license,
      ));
    }
    return found;
  }
}
