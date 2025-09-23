// lib/features/super_interests/super_interests_models.dart
import 'package:flutter/foundation.dart';

/// Tipos de super-interés disponibles
enum SuperInterestType { none, football, music, gaming }

extension SuperInterestTypeX on SuperInterestType {
  String get asKey {
    switch (this) {
      case SuperInterestType.none:
        return 'none';
      case SuperInterestType.football:
        return 'football';
      case SuperInterestType.music:
        return 'music';
      case SuperInterestType.gaming:
        return 'gaming';
    }
  }

  static SuperInterestType fromKey(String? v) {
    switch (v) {
      case 'football':
        return SuperInterestType.football;
      case 'music':
        return SuperInterestType.music;
      case 'gaming':
        return SuperInterestType.gaming;
      default:
        return SuperInterestType.none;
    }
  }
}

/// --- Datos de FÚTBOL ---
@immutable
class FootballPref {
  final String? team; // p.ej. 'FC Barcelona'
  final String? idol; // p.ej. 'Xavi Hernández'
  final List<String> tags; // p.ej. ['Liga Fantasy','Practico fútbol']

  const FootballPref({this.team, this.idol, this.tags = const []});

  Map<String, dynamic> toJson() => {
    'team': team,
    'idol': idol,
    'tags': tags,
  };

  factory FootballPref.fromJson(Map<String, dynamic>? m) {
    m ??= const {};
    return FootballPref(
      team: m['team'] as String?,
      idol: m['idol'] as String?,
      tags: (m['tags'] as List?)?.cast<String>() ?? const [],
    );
  }

  FootballPref copyWith({String? team, String? idol, List<String>? tags}) =>
      FootballPref(
        team: team ?? this.team,
        idol: idol ?? this.idol,
        tags: tags ?? this.tags,
      );
}

/// --- Datos de MÚSICA ---
@immutable
class MusicPref {
  final bool spotifyConnected;
  final String? favoriteGenre;
  final String? favoriteArtist;
  final String? definingSong;
  final String? spotifyUserId;
  final DateTime? lastSync;

  const MusicPref({
    this.spotifyConnected = false,
    this.favoriteGenre,
    this.favoriteArtist,
    this.definingSong,
    this.spotifyUserId,
    this.lastSync,
  });

  Map<String, dynamic> toJson() => {
    'spotifyConnected': spotifyConnected,
    'favoriteGenre': favoriteGenre,
    'favoriteArtist': favoriteArtist,
    'definingSong': definingSong,
    'spotifyUserId': spotifyUserId,
    'lastSync': lastSync?.toIso8601String(),
  };

  factory MusicPref.fromJson(Map<String, dynamic>? m) {
    m ??= const {};
    return MusicPref(
      spotifyConnected: (m['spotifyConnected'] as bool?) ?? false,
      favoriteGenre: m['favoriteGenre'] as String?,
      favoriteArtist: m['favoriteArtist'] as String?,
      definingSong: m['definingSong'] as String?,
      spotifyUserId: m['spotifyUserId'] as String?,
      lastSync: (m['lastSync'] as String?) != null
          ? DateTime.tryParse(m['lastSync'] as String)
          : null,
    );
  }

  MusicPref copyWith({
    bool? spotifyConnected,
    String? favoriteGenre,
    String? favoriteArtist,
    String? definingSong,
    String? spotifyUserId,
    DateTime? lastSync,
  }) =>
      MusicPref(
        spotifyConnected: spotifyConnected ?? this.spotifyConnected,
        favoriteGenre: favoriteGenre ?? this.favoriteGenre,
        favoriteArtist: favoriteArtist ?? this.favoriteArtist,
        definingSong: definingSong ?? this.definingSong,
        spotifyUserId: spotifyUserId ?? this.spotifyUserId,
        lastSync: lastSync ?? this.lastSync,
      );
}

/// --- Datos de VIDEOJUEGOS ---
@immutable
class GamingPref {
  final Set<String> platforms; // {'PlayStation','Xbox','Switch','PC','Móvil'}
  final String? favoriteGame;
  final String? mostPlayed;

  const GamingPref({
    this.platforms = const {},
    this.favoriteGame,
    this.mostPlayed,
  });

  Map<String, dynamic> toJson() => {
    'platforms': platforms.toList(),
    'favoriteGame': favoriteGame,
    'mostPlayed': mostPlayed,
  };

  factory GamingPref.fromJson(Map<String, dynamic>? m) {
    m ??= const {};
    return GamingPref(
      platforms: (m['platforms'] as List?)?.cast<String>().toSet() ?? {},
      favoriteGame: m['favoriteGame'] as String?,
      mostPlayed: m['mostPlayed'] as String?,
    );
  }

  GamingPref copyWith({
    Set<String>? platforms,
    String? favoriteGame,
    String? mostPlayed,
  }) =>
      GamingPref(
        platforms: platforms ?? this.platforms,
        favoriteGame: favoriteGame ?? this.favoriteGame,
        mostPlayed: mostPlayed ?? this.mostPlayed,
      );
}

/// --- Contenedor unificado ---
@immutable
class SuperInterestData {
  final SuperInterestType type;
  final FootballPref? football;
  final MusicPref? music;
  final GamingPref? gaming;

  const SuperInterestData({
    required this.type,
    this.football,
    this.music,
    this.gaming,
  });

  Map<String, dynamic> toJson() => {
    'type': type.asKey,
    'football': football?.toJson(),
    'music': music?.toJson(),
    'gaming': gaming?.toJson(),
  };

  factory SuperInterestData.fromJson(Map<String, dynamic>? m) {
    m ??= const {};
    final t = SuperInterestTypeX.fromKey(m['type'] as String?);
    return SuperInterestData(
      type: t,
      football: FootballPref.fromJson(m['football'] as Map<String, dynamic>?),
      music: MusicPref.fromJson(m['music'] as Map<String, dynamic>?),
      gaming: GamingPref.fromJson(m['gaming'] as Map<String, dynamic>?),
    );
  }

  SuperInterestData copyWith({
    SuperInterestType? type,
    FootballPref? football,
    MusicPref? music,
    GamingPref? gaming,
  }) =>
      SuperInterestData(
        type: type ?? this.type,
        football: football ?? this.football,
        music: music ?? this.music,
        gaming: gaming ?? this.gaming,
      );
}
