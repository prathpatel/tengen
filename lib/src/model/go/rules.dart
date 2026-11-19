/// The rule sets supported by online-go.com.
///
/// The defaults below follow the ones the OGS `goban` engine applies for each rule set.
enum Ruleset {
  japanese('Japanese', komi: 6.5, areaScoring: false, superko: false, allowSuicide: false),
  chinese('Chinese', komi: 7.5, areaScoring: true, superko: true, allowSuicide: false),
  aga('AGA', komi: 7.5, areaScoring: true, superko: true, allowSuicide: false),
  korean('Korean', komi: 6.5, areaScoring: false, superko: false, allowSuicide: false),
  nz('New Zealand', komi: 7, areaScoring: true, superko: true, allowSuicide: true),
  ing('Ing SST', komi: 7.5, areaScoring: true, superko: true, allowSuicide: true);

  const Ruleset(
    this.label, {
    required this.komi,
    required this.areaScoring,
    required this.superko,
    required this.allowSuicide,
  });

  final String label;

  /// Default komi for an even game.
  final double komi;

  /// Area scoring (stones + territory) if true, territory scoring (territory + prisoners)
  /// otherwise.
  final bool areaScoring;

  /// Whether positional superko forbids repeating any earlier position. When false only the
  /// simple ko rule applies.
  final bool superko;

  /// Whether multi-stone suicide is a legal move.
  final bool allowSuicide;

  /// Points given to white for black's handicap stones, under area scoring.
  int handicapCompensation(int handicap) => switch (this) {
    chinese || ing => handicap > 1 ? handicap : 0,
    aga => handicap > 1 ? handicap - 1 : 0,
    _ => 0,
  };

  /// Default komi for a game with [handicap] stones: a handicap game keeps only the half point.
  double defaultKomi(int handicap) => handicap > 1 ? komi - komi.floorToDouble() : komi;

  /// Parses the OGS `rules` field.
  static Ruleset fromOgs(String? value) =>
      Ruleset.values.firstWhere((r) => r.name == value?.toLowerCase(), orElse: () => japanese);
}
