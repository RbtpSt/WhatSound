import 'package:flutter_test/flutter_test.dart';
import 'package:whatsound/internet_audio.dart';
import 'package:whatsound/result_interleave.dart';

OnlineSound item(String source, int n) => OnlineSound(title: '$source $n', url: 'https://example.org/$source/$n.mp3', source: source, license: '');

void main() {
  test('Alterna tres audios por fuente sin perder ninguno', () {
    final sounds = [
      for (var i = 0; i < 5; i++) item('101soundboards', i),
      for (var i = 0; i < 7; i++) item('Myinstants', i),
      for (var i = 0; i < 2; i++) item('Wikimedia Commons', i),
    ];
    final actual = interleaveResults(sounds);
    expect(actual.length, 14);
    expect(actual.take(3).map((s) => s.source).toList(), everyElement('Myinstants'));
    expect(actual.skip(3).take(3).map((s) => s.source).toList(), everyElement('101soundboards'));
    expect(actual.skip(6).take(2).map((s) => s.source).toList(), everyElement('Wikimedia Commons'));
    expect(actual.skip(8).take(3).map((s) => s.source).toList(), everyElement('Myinstants'));
    expect(actual.map((s) => s.url).toSet().length, 14);
  });
  test('Omite proveedores vacíos y URLs duplicadas', () {
    final sound = item('Myinstants', 0);
    final actual = interleaveResults([sound, sound, item('101soundboards', 1)]);
    expect(actual.length, 2);
  });
}
