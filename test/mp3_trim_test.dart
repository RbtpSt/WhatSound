import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsound/mp3_trim.dart';

void main() {
  test('Recorta fotogramas MP3 sin alterar el audio cuando el ajuste es cero', () {
    final sample = File('${Directory.systemTemp.path}/whatsound_101_sample.mp3');
    if (!sample.existsSync()) return;
    final original = sample.readAsBytesSync();
    expect(trimMp3Start(original, Duration.zero), original);
    final cut = trimMp3Start(original, const Duration(milliseconds: 400));
    expect(cut.length, lessThan(original.length));
    expect(cut.length, greaterThan(1000));
    expect(cut[0], 0xff);
  });
}
