import 'package:http/http.dart' as http;
import 'internet_audio.dart';

class InstantAudioSearch {
  final http.Client client;
  InstantAudioSearch(this.client);

  Future<List<OnlineSound>> search(String phrase) async {
    final uri = Uri.https('www.myinstants.com', '/en/search/', {'name': phrase});
    final response = await client.get(uri, headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; WhatSound/0.2)',
    }).timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) return [];
    final html = response.body;
    final pattern = RegExp(
      r'''onclick="play\('(/media/sounds/[^']+)'[^>]*>[\s\S]*?<a href="([^"]+)" class="instant-link[^\"]*">([^<]+)</a>''',
      caseSensitive: false,
    );
    final found = <OnlineSound>[];
    for (final match in pattern.allMatches(html)) {
      final path = match.group(1)!;
      final title = _decode(match.group(3)!);
      if (found.any((e) => e.url.endsWith(path))) continue;
      found.add(OnlineSound(
        title: title,
        url: Uri.https('www.myinstants.com', path).toString(),
        source: 'Myinstants · frase corta',
        license: 'Derechos del audio: verificar antes de redistribuir',
      ));
    }
    return found.take(35).toList();
  }

  String _decode(String text) => text.replaceAll('&amp;', '&').replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>');
}
