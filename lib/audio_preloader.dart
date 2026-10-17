import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads bounded, short audio files once for both playback and sharing.
class AudioPreloader {
  final http.Client client;
  final Map<String, File> _ready = {};
  final Map<String, Future<File>> _pending = {};
  AudioPreloader({http.Client? client}) : client = client ?? http.Client();

  bool isReady(String url) => _ready[url]?.existsSync() ?? false;
  bool isPending(String url) => _pending.containsKey(url);
  File? cached(String url) => isReady(url) ? _ready[url] : null;

  Future<File> prepare(String url) {
    final existing = cached(url);
    if (existing != null) return Future.value(existing);
    return _pending.putIfAbsent(url, () async {
      File? file;
      final httpClient = client;
      try {
        final uri = Uri.parse(url);
        if (uri.scheme != 'https' && uri.scheme != 'http') throw const FormatException('URL no compatible');
        final ext = uri.path.toLowerCase().endsWith('.ogg') ? '.ogg'
            : uri.path.toLowerCase().endsWith('.wav') ? '.wav'
            : uri.path.toLowerCase().endsWith('.m4a') ? '.m4a' : '.mp3';
        final response = await httpClient.send(http.Request('GET', uri)).timeout(const Duration(seconds: 18));
        if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: uri);
        final dir = await getTemporaryDirectory();
        file = File('${dir.path}/whatsound_cached_${DateTime.now().microsecondsSinceEpoch}_${url.hashCode.abs()}$ext');
        final sink = file.openWrite();
        var total = 0;
        try {
          await for (final chunk in response.stream.timeout(const Duration(seconds: 15))) {
            total += chunk.length;
            if (total > 8 * 1024 * 1024) throw const HttpException('Audio demasiado grande');
            sink.add(chunk);
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
        if (total < 100) throw const FormatException('Audio vacío');
        _ready[url] = file;
        return file;
      } catch (_) {
        if (file != null && await file.exists()) await file.delete();
        rethrow;
      } finally {
        _pending.remove(url);
      }
    });
  }

  void dispose() => client.close();
}
