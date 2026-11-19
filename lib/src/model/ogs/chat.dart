import 'package:meta/meta.dart';
import 'package:tengen/src/utils/json.dart';

/// A line of a game chat (`game/<id>/chat` event).
@immutable
class GameChatLine {
  const GameChatLine({
    required this.id,
    required this.channel,
    required this.playerId,
    required this.username,
    required this.text,
    required this.date,
    this.moveNumber,
    this.isBot = false,
  });

  /// Parses `{channel, line}`. Returns null for lines without displayable text.
  static GameChatLine? fromEvent(Object? event) {
    final json = asMap(event);
    final line = asMap(json?['line']);
    if (json == null || line == null) return null;
    final text = bodyText(line['body']);
    if (text == null || text.trim().isEmpty) return null;
    final date = asInt(line['date']) ?? 0;
    final playerId = asInt(line['player_id']) ?? 0;
    return GameChatLine(
      id: line['chat_id'] as String? ?? '$playerId-$date-${text.hashCode}',
      channel: json['channel'] as String? ?? line['channel'] as String? ?? 'main',
      playerId: playerId,
      username: line['username'] as String? ?? '?',
      text: text,
      // OGS sends seconds.
      date: DateTime.fromMillisecondsSinceEpoch(date * 1000),
      moveNumber: asInt(line['move_number']),
      isBot: line['ui_class'] == 'bot',
    );
  }

  /// The text of a chat body: a string, a translated message (`{"en": ..., "fr": ...}`) or an
  /// analysis comment (`{"type": "analysis", "name": ...}`).
  static String? bodyText(Object? body) {
    if (body is String) return body;
    final map = asMap(body);
    if (map == null) return null;
    if (map['type'] == 'analysis' || map['type'] == 'review') return map['name'] as String?;
    final en = map['en'];
    if (en is String) return en;
    return map.values.whereType<String>().firstOrNull;
  }

  final String id;

  /// `main` (players), `spectator`, or `malkovich` (hidden player comments, not shown).
  final String channel;
  final int playerId;
  final String username;
  final String text;
  final DateTime date;
  final int? moveNumber;
  final bool isBot;

  bool get isSpectator => channel == 'spectator';
}

/// The chat channels shown in the app.
const visibleChatChannels = {'main', 'spectator'};
