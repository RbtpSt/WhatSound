import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'commons_audio.dart';
import 'instant_audio.dart';
import 'soundboards_audio.dart';

class OnlineSound {
  final String title;
  final String url;
  final String source;
  final String license;
  const OnlineSound({required this.title, required this.url, required this.source, required this.license});
  Map<String, dynamic> toJson() => {'title': title, 'url': url, 'source': source, 'license': license};
  factory OnlineSound.fromJson(Map<String, dynamic> json) => OnlineSound(
    title: json['title'] as String? ?? '',
    url: json['url'] as String? ?? '',
    source: json['source'] as String? ?? '',
    license: json['license'] as String? ?? '',
  );
}

class OnlineAudioService {
  static const _cacheKey = 'verified_audio_links_v1';
  final http.Client client;
  OnlineAudioService({http.Client? client}) : client = client ?? http.Client();

  Future<List<OnlineSound>> verifiedLinks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_cacheKey) ?? [];
    return raw.map((e) => OnlineSound.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
  }

  Future<void> saveVerified(OnlineSound sound) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await verifiedLinks();
    existing.removeWhere((e) => e.url == sound.url);
    existing.insert(0, sound);
    await prefs.setStringList(_cacheKey, existing.take(300).map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<List<OnlineSound>> search(String query, {void Function(List<OnlineSound>)? onResults}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final cached = (await verifiedLinks()).where((s) =>
      s.title.toLowerCase().contains(trimmed.toLowerCase())).toList();
    final results = <OnlineSound>[];
    final seen = <String>{};
    void addBatch(List<OnlineSound> sounds) {
      for (final sound in sounds) {
        if (seen.add(sound.url)) results.add(sound);
      }
      if (results.isNotEmpty) onResults?.call(List.unmodifiable(results));
    }

    // The two fast soundboard providers run concurrently. Display the first
    // available results immediately, then append more without reordering UI.
    // Each provider contributes up to three results per round.
    final pending = <String, List<OnlineSound>>{};
    final offsets = <String, int>{'myinstants': 0, '101soundboards': 0};
    void emitFastBatches() {
      for (var round = 0; round < (pending.length < 2 ? 1 : 100); round++) {
        var progressed = false;
        for (final key in ['myinstants', '101soundboards']) {
          final batch = pending[key];
          if (batch == null) continue;
          final offset = offsets[key] ?? 0;
          if (offset >= batch.length) continue;
          final next = (offset + 3).clamp(0, batch.length);
          addBatch(batch.sublist(offset, next));
          offsets[key] = next;
          progressed = true;
        }
        if (!progressed) break;
      }
    }
    addBatch(cached);
    Future<void> fast(String key, Future<List<OnlineSound>> future) async {
      try {
        pending[key] = await future;
        emitFastBatches();
      } catch (_) { /* Continue with other sources. */ }
    }
    await Future.wait([
      fast('myinstants', InstantAudioSearch(client).search(trimmed)),
      fast('101soundboards', SoundboardsAudioSearch(client).search(trimmed)),
    ]);
    try {
    final searchQuery = 'mediatype:audio AND (title:("${_safeQuery(trimmed)}") OR description:("${_safeQuery(trimmed)}"))';
    final uri = Uri.https('archive.org', '/advancedsearch.php', {
      'q': searchQuery,
      'fl[]': ['identifier', 'title'],
      'rows': '12',
      'output': 'json',
    });
    final response = await client.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw Exception('La búsqueda respondió ${response.statusCode}');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final responseNode = body['response'] as Map<String, dynamic>? ?? {};
    final docs = responseNode['docs'] as List<dynamic>? ?? [];
    for (final item in docs) {
      final doc = item as Map<String, dynamic>;
      final id = doc['identifier'] as String?;
      if (id == null || id.isEmpty) continue;
      try {
        final metaResponse = await client.get(Uri.https('archive.org', '/metadata/$id'))
          .timeout(const Duration(seconds: 12));
        if (metaResponse.statusCode != 200) continue;
        final meta = jsonDecode(metaResponse.body) as Map<String, dynamic>;
        final metadata = meta['metadata'] as Map<String, dynamic>? ?? {};
        final license = metadata['licenseurl']?.toString() ?? metadata['rights']?.toString() ?? '';
        final files = meta['files'] as List<dynamic>? ?? [];
        final candidates = files.whereType<Map<String, dynamic>>().where((f) {
          final name = (f['name'] ?? '').toString().toLowerCase();
          return name.endsWith('.mp3') || name.endsWith('.ogg') || name.endsWith('.m4a') || name.endsWith('.wav');
        }).take(3);
        for (final f in candidates) {
          final filename = f['name'].toString();
          final url = Uri.https('archive.org', '/download/$id/$filename').toString();
          if (results.any((s) => s.url == url)) continue;
          final size = int.tryParse(f['size']?.toString() ?? '') ?? 999999999;
          if (size > 4 * 1024 * 1024) continue;
          addBatch([OnlineSound(
            title: (f['title']?.toString().isNotEmpty == true ? f['title'] : doc['title'] ?? filename).toString(),
            url: url,
            source: 'Internet Archive · $id',
            license: license,
          )]);
        }
      } catch (_) {
        continue;
      }
    }
    } catch (_) { /* Internet Archive unavailable; continue with Commons. */ }
    try {
      final commons = await CommonsAudioSearch(client).search(trimmed);
      addBatch(commons);
    } catch (_) { /* Other sources remain usable. */ }
    return results;
  }

  String _safeQuery(String query) => query.replaceAll(RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ ]'), ' ').trim();
}
