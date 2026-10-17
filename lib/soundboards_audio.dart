import 'dart:convert';
import 'package:http/http.dart' as http;
import 'internet_audio.dart';

class SoundboardsAudioSearch {
  final http.Client client;
  SoundboardsAudioSearch(this.client);

  Future<List<OnlineSound>> search(String phrase) async {
    final uri = Uri.https('www.101soundboards.com', '/search/$phrase');
    final response = await client.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; WhatSound/0.3)',
    }).timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) return [];
    final html = response.body;
    final scripts = RegExp(r'<script[^>]*type="application/ld\+json"[^>]*>([\s\S]*?)</script>', caseSensitive: false);
    final results = <OnlineSound>[];
    for (final script in scripts.allMatches(html)) {
      try {
        final data = jsonDecode(script.group(1)!) as Map<String, dynamic>;
        final graph = data['@graph'] as List<dynamic>? ?? [data];
        for (final entry in graph) {
          if (entry is! Map<String, dynamic> || entry['@type'] != 'ItemList') continue;
          final items = entry['itemListElement'] as List<dynamic>? ?? [];
          for (final row in items) {
            if (row is! Map<String, dynamic>) continue;
            final item = row['item'];
            if (item is! Map<String, dynamic>) continue;
            final audio = (item['contentUrl'] ?? '').toString();
            final title = (item['name'] ?? '').toString();
            final link = Uri.tryParse(audio);
            if (link == null || link.scheme != 'https' || !audio.toLowerCase().endsWith('.mp3') || title.isEmpty) continue;
            if (results.any((s) => s.url == audio)) continue;
            results.add(OnlineSound(
              title: title.replaceAll(RegExp(r' - [^-]+ Soundboard$'), ''),
              url: audio,
              source: '101soundboards · frase corta',
              license: 'Derechos del audio: verificar antes de redistribuir',
            ));
          }
        }
      } catch (_) { continue; }
    }
    return results.take(40).toList();
  }
}
