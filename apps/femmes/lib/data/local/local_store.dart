import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api/models.dart';

/// Ticket d'une question envoyée à un conseiller.
///
/// CONFIDENTIALITÉ : un ticket ne contient QUE l'identifiant, le jeton, le
/// module et la date. Jamais le texte de la question, ni la transcription, ni
/// la réponse : un téléphone est souvent partagé (adolescentes). La réponse
/// du conseiller est relue sur le serveur à chaque affichage.
class Ticket {
  const Ticket({
    required this.questionId,
    required this.token,
    required this.module,
    required this.createdAt,
  });
  final String questionId;
  final String token;
  final Module module;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'token': token,
        'module': module.name,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        questionId: j['question_id'] as String,
        token: j['token'] as String,
        module: Module.parse(j['module'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Site choisi (« Où habitez-vous ? »), gardé seulement sur le téléphone.
class SavedSite {
  const SavedSite(this.id, this.name);
  final String id;
  final String name;
}

/// Accord pour la voix, avec la version de l'information présentée.
class VoiceConsent {
  const VoiceConsent({required this.version, required this.acceptedAt});
  final String version;
  final DateTime acceptedAt;
}

/// Stockage local minimal (`shared_preferences`).
///
/// Pas de base de données ni de chiffrement : rien d'identifiant ni de
/// sensible n'est gardé (voir README, « Modèle d'anonymat »). Le jeton d'un
/// ticket ne permet que de relire ou d'effacer la question correspondante.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static const _kOnboarded = 'fanilo.onboarded.v1';
  static const _kLocale = 'fanilo.locale.v1';
  static const _kConsentVersion = 'fanilo.voice_consent.version.v1';
  static const _kConsentAt = 'fanilo.voice_consent.at.v1';
  static const _kSiteId = 'fanilo.site.id.v1';
  static const _kSiteName = 'fanilo.site.name.v1';
  static const _kTickets = 'fanilo.tickets.v1';
  static const _kRead = 'fanilo.read_answers.v1';

  /// Seules clés écrites (les tests vérifient qu'aucune autre n'apparaît).
  static const allowedKeys = {
    _kOnboarded,
    _kLocale,
    _kConsentVersion,
    _kConsentAt,
    _kSiteId,
    _kSiteName,
    _kTickets,
    _kRead,
  };

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded() => _prefs.setBool(_kOnboarded, true);

  /// `mg` par défaut.
  String get locale => _prefs.getString(_kLocale) ?? 'mg';
  Future<void> setLocale(String code) => _prefs.setString(_kLocale, code);

  VoiceConsent? get voiceConsent {
    final v = _prefs.getString(_kConsentVersion);
    final at = _prefs.getString(_kConsentAt);
    if (v == null || at == null) return null;
    return VoiceConsent(version: v, acceptedAt: DateTime.parse(at));
  }

  Future<void> setVoiceConsent(VoiceConsent? c) async {
    if (c == null) {
      await _prefs.remove(_kConsentVersion);
      await _prefs.remove(_kConsentAt);
    } else {
      await _prefs.setString(_kConsentVersion, c.version);
      await _prefs.setString(_kConsentAt, c.acceptedAt.toUtc().toIso8601String());
    }
  }

  SavedSite? get site {
    final id = _prefs.getString(_kSiteId);
    final name = _prefs.getString(_kSiteName);
    return id == null || name == null ? null : SavedSite(id, name);
  }

  Future<void> setSite(SavedSite? s) async {
    if (s == null) {
      await _prefs.remove(_kSiteId);
      await _prefs.remove(_kSiteName);
    } else {
      await _prefs.setString(_kSiteId, s.id);
      await _prefs.setString(_kSiteName, s.name);
    }
  }

  List<Ticket> get tickets {
    final raw = _prefs.getString(_kTickets);
    if (raw == null) return const [];
    try {
      return [
        for (final t in jsonDecode(raw) as List) Ticket.fromJson(t as Map<String, dynamic>)
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveTickets(List<Ticket> tickets) =>
      _prefs.setString(_kTickets, jsonEncode([for (final t in tickets) t.toJson()]));

  Future<void> addTicket(Ticket t) =>
      _saveTickets([t, ...tickets.where((e) => e.questionId != t.questionId)]);

  Future<void> removeTicket(String questionId) async {
    await _saveTickets(tickets.where((t) => t.questionId != questionId).toList());
    await _prefs.setStringList(_kRead, readAnswers.where((id) => id != questionId).toList());
  }

  Future<void> clearTickets() async {
    await _prefs.remove(_kTickets);
    await _prefs.remove(_kRead);
  }

  /// Questions dont la réponse a déjà été vue : identifiants SEULEMENT
  /// (jamais la réponse elle-même).
  Set<String> get readAnswers => (_prefs.getStringList(_kRead) ?? const []).toSet();

  Future<void> markRead(Iterable<String> questionIds) =>
      _prefs.setStringList(_kRead, {...readAnswers, ...questionIds}.toList());
}
