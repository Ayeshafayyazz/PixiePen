/// Classic Levenshtein edit distance (insert / delete / substitute).
/// Used to catch intentional typos around blocked words (e.g. `fuuk` → `fuck`).
int levenshteinDistance(String a, String b) {
  if (identical(a, b)) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (j) => j);
  var curr = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = curr[j - 1] + 1;
      final ins = prev[j] + 1;
      final sub = prev[j - 1] + cost;
      curr[j] = del < ins
          ? (del < sub ? del : sub)
          : (ins < sub ? ins : sub);
    }
    final swap = prev;
    prev = curr;
    curr = swap;
  }
  return prev[n];
}
