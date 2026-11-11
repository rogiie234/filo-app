// Drift's generated JSON uses camelCase keys and epoch milliseconds for dates.
Map<String, dynamic> cacheRowJson(
  Map<String, dynamic> row, {
  Set<String> extraDateFields = const {},
}) => {
  for (final entry in row.entries)
    entry.key.replaceAllMapped(RegExp(r'_([a-z])'), (m) => m[1]!.toUpperCase()):
        (entry.key.endsWith('_at') || extraDateFields.contains(entry.key)) &&
            entry.value != null
        ? DateTime.parse(entry.value as String).millisecondsSinceEpoch
        : entry.value,
};
