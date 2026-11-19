import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:tengen/src/utils/json.dart';

/// A player as returned by the OGS APIs.
@immutable
class OgsUser {
  const OgsUser({
    required this.id,
    required this.username,
    this.ranking,
    this.rating,
    this.deviation,
    this.professional = false,
    this.isBot = false,
    this.country,
    this.iconUrl,
    this.anonymous = false,
  });

  /// Parses any of the player shapes OGS sends (`ui/config` user, REST player, game data player,
  /// game list player).
  factory OgsUser.fromJson(Map<String, dynamic> json) {
    final ratings = json['ratings'];
    final overall = ratings is Map ? ratings['overall'] : null;
    return OgsUser(
      id: asInt(json['id']) ?? 0,
      username: json['username'] as String? ?? '?',
      ranking: asDouble(json['ranking'] ?? json['rank']),
      rating: overall is Map ? asDouble(overall['rating']) : null,
      deviation: overall is Map ? asDouble(overall['deviation']) : null,
      professional: json['professional'] == true || json['pro'] == 1 || json['pro'] == true,
      isBot: json['is_bot'] == true || json['ui_class'] == 'bot',
      country: json['country'] as String?,
      iconUrl: (json['icon'] ?? json['icon-url']) as String?,
      anonymous: json['anonymous'] == true,
    );
  }

  final int id;
  final String username;

  /// OGS rank number: 30 is 1 dan, 29 is 1 kyu.
  final double? ranking;

  /// Glicko-2 overall rating and deviation, when known.
  final double? rating;
  final double? deviation;
  final bool professional;
  final bool isBot;
  final String? country;
  final String? iconUrl;
  final bool anonymous;

  /// Rank label such as `5k`, `2d` or `3p`, `?` when provisional.
  String get rankLabel {
    final dev = deviation;
    if (dev != null && dev >= provisionalDeviation && !professional) return '?';
    final r = rating;
    if (r != null && !professional) return rankLabelFor(ratingToRank(r));
    final rank = ranking;
    if (rank == null) return '';
    return rankLabelFor(rank, professional: professional);
  }

  String get displayName {
    final rank = rankLabel;
    return rank.isEmpty ? username : '$username [$rank]';
  }

  @override
  bool operator ==(Object other) =>
      other is OgsUser && other.id == id && other.username == username;

  @override
  int get hashCode => Object.hash(id, username);
}

/// A rating deviation at or above this is considered provisional, as on OGS.
const provisionalDeviation = 160;

/// Converts a Glicko-2 rating to an OGS rank number (same formula as the OGS website).
double ratingToRank(double rating) => math.log(rating.clamp(100, 6000) / 525) * 23.15;

/// Formats an OGS rank number.
String rankLabelFor(double rank, {bool professional = false}) {
  if (professional || rank > 900) {
    final pro = rank > 900 ? rank - 1000 - 36 : rank - 36;
    return '${pro.floor().clamp(1, 9)}p';
  }
  if (rank < -900) return '?';
  if (rank < 30) return '${(30 - rank).ceil()}k';
  return '${(rank - 29).floor()}d';
}
