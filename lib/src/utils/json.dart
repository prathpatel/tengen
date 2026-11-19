/// Lenient JSON number parsing: OGS sends some numbers as strings (e.g. `"komi": "6.50"`).
int? asInt(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v) ?? double.tryParse(v)?.toInt(),
  _ => null,
};

double? asDouble(Object? value) => switch (value) {
  final num v => v.toDouble(),
  final String v => double.tryParse(v),
  _ => null,
};

Map<String, dynamic>? asMap(Object? value) =>
    value is Map ? value.map((k, v) => MapEntry(k.toString(), v)) : null;

List<Object?> asList(Object? value) => value is List ? value : const [];
