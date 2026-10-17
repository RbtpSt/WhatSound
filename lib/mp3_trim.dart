import 'dart:typed_data';

/// Removes complete MPEG audio frames before [start] without re-encoding.
/// Designed for short MP3 soundboard clips. Throws for unsupported streams.
Uint8List trimMp3Start(Uint8List bytes, Duration start) {
  if (start <= Duration.zero) return bytes;
  var pos = 0;
  if (bytes.length > 10 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
    pos = 10 + ((bytes[6] & 127) << 21) + ((bytes[7] & 127) << 14) + ((bytes[8] & 127) << 7) + (bytes[9] & 127);
    if ((bytes[5] & 0x10) != 0) pos += 10;
  }
  final targetSeconds = start.inMilliseconds / 1000;
  var seconds = 0.0;
  var frames = 0;
  while (pos + 4 <= bytes.length) {
    final h = (bytes[pos] << 24) | (bytes[pos + 1] << 16) | (bytes[pos + 2] << 8) | bytes[pos + 3];
    if ((h & 0xffe00000) != 0xffe00000) throw const FormatException('Audio MP3 no compatible con recorte');
    final version = (h >> 19) & 3;
    final layer = (h >> 17) & 3;
    final bitrateIndex = (h >> 12) & 15;
    final sampleIndex = (h >> 10) & 3;
    if (version == 1 || layer != 1 || bitrateIndex == 0 || bitrateIndex == 15 || sampleIndex == 3) {
      throw const FormatException('Formato MP3 no compatible con recorte');
    }
    final rates = version == 3 ? [44100, 48000, 32000] : version == 2 ? [22050, 24000, 16000] : [11025, 12000, 8000];
    final kbps = version == 3
        ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    final samples = version == 3 ? 1152 : 576;
    final frameSize = ((version == 3 ? 144000 : 72000) * kbps[bitrateIndex] / rates[sampleIndex]).floor() + ((h >> 9) & 1);
    if (frameSize < 4 || pos + frameSize > bytes.length) throw const FormatException('Archivo MP3 incompleto');
    if (seconds + samples / rates[sampleIndex] >= targetSeconds) break;
    pos += frameSize;
    seconds += samples / rates[sampleIndex];
    frames++;
  }
  if (frames == 0 || pos >= bytes.length - 200) throw const FormatException('No se puede recortar ese intervalo');
  return Uint8List.sublistView(bytes, pos);
}
