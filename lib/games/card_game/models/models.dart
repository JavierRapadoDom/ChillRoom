// lib/games/card_game/models/models.dart
import 'package:equatable/equatable.dart';

enum CardKind { black, white }

class PromptCard extends Equatable {
  final String id;
  final String text;
  final int selectCount;
  final List<String> tags;
  const PromptCard({required this.id, required this.text, required this.selectCount, this.tags = const []});
  @override
  List<Object?> get props => [id, text, selectCount];
}

class WhiteCard extends Equatable {
  final String id;
  final String text;
  const WhiteCard({required this.id, required this.text});
  @override
  List<Object?> get props => [id, text];
}

class PlayerPublic extends Equatable {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final bool isJudge;
  const PlayerPublic({required this.userId, required this.displayName, this.avatarUrl, required this.score, required this.isJudge});
  @override
  List<Object?> get props => [userId, displayName, avatarUrl, score, isJudge];
}

class RoundState extends Equatable {
  final String roundId;
  final int roundNo;
  final String judgeId;
  final PromptCard prompt;
  final String state; // 'deal'|'submit'|'reveal'|'judging'|'scoring'
  final int selectCount;
  final DateTime startedAt;
  const RoundState({
    required this.roundId,
    required this.roundNo,
    required this.judgeId,
    required this.prompt,
    required this.state,
    required this.selectCount,
    required this.startedAt,
  });
  @override
  List<Object?> get props => [roundId, roundNo, judgeId, state, selectCount];
}

class SubmissionPublic extends Equatable {
  final String id;
  final String playerId;
  final List<String> cardText; // snapshot
  final bool isWinner;
  const SubmissionPublic({required this.id, required this.playerId, required this.cardText, required this.isWinner});
  @override
  List<Object?> get props => [id, playerId, isWinner];
}
