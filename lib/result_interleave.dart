import 'internet_audio.dart';

/// Alternates groups of three results per provider, preserving provider order.
/// Cached links are grouped with their original source rather than appearing
/// as an unrelated block. URLs are de-duplicated across all providers.
List<OnlineSound> interleaveResults(List<OnlineSound> sounds, {int groupSize = 3}) {
  if (groupSize < 1) throw ArgumentError.value(groupSize, 'groupSize');
  final groups = <String, List<OnlineSound>>{};
  final seen = <String>{};
  for (final sound in sounds) {
    if (!seen.add(sound.url)) continue;
    final source = sound.source.toLowerCase();
    final key = source.contains('myinstants') ? 'myinstants'
        : source.contains('101soundboards') ? '101soundboards'
        : source.contains('wikimedia') ? 'wikimedia'
        : source.contains('internet archive') ? 'archive'
        : source;
    groups.putIfAbsent(key, () => []).add(sound);
  }
  final orderedKeys = <String>[
    'myinstants', '101soundboards', 'wikimedia', 'archive',
    ...groups.keys.where((key) => !['myinstants', '101soundboards', 'wikimedia', 'archive'].contains(key)),
  ];
  final offsets = <String, int>{};
  final output = <OnlineSound>[];
  var remaining = seen.length;
  while (remaining > 0) {
    for (final key in orderedKeys) {
      final list = groups[key];
      if (list == null) continue;
      final offset = offsets[key] ?? 0;
      if (offset >= list.length) continue;
      final end = (offset + groupSize).clamp(0, list.length);
      output.addAll(list.sublist(offset, end));
      remaining -= end - offset;
      offsets[key] = end;
    }
  }
  return output;
}
