import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models.dart';

/// Erreurs de l'API publique, traduites en messages simples par l'interface.
enum ApiErrorKind {
  /// Pas de réseau, serveur injoignable ou délai dépassé.
  network,

  /// 429 : trop de questions depuis cette connexion.
  rateLimited,

  /// 422 `consent_required` : audio sans consentement vocal.
  consentRequired,

  /// 503 : référentiel non servi (statut non validé hors mode démo).
  unavailable,

  /// 404 : question inconnue ou jeton faux (déjà effacée, par exemple).
  notFound,

  /// Toute autre réponse inattendue.
  other,
}

class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.detail});
  final ApiErrorKind kind;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => 'ApiException($kind, $statusCode, $detail)';
}

/// Contrat de l'API publique anonyme. Aucune authentification.
abstract interface class PublicApi {
  Future<List<Site>> sites();
  Future<List<InformationItem>> information();
  Future<Menu> menus(Module module, String language);
  Future<AskResult> askText(
      {required Module module, required String text, required String language, String? siteId});
  Future<AskResult> askVoice(
      {required Module module,
      required VoiceClip clip,
      required String language,
      String? siteId,
      required bool voiceConsent});
  Future<QuestionStatus> question(String questionId, String token);
  Future<void> deleteQuestion(String questionId, String token);
}

class HttpPublicApi implements PublicApi {
  HttpPublicApi(this.baseUrl,
      {http.Client? client,
      this.timeout = const Duration(seconds: 30),
      this.voiceTimeout = const Duration(seconds: 90)})
      : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// La transcription (Whisper sur CPU) peut prendre 10 à 20 s ou plus.
  final Duration voiceTimeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.path.endsWith('/')
        ? baseUrl.path.substring(0, baseUrl.path.length - 1)
        : baseUrl.path;
    return baseUrl.replace(path: '$base$path', queryParameters: query);
  }

  Future<http.Response> _send(Future<http.Response> Function() call, {Duration? timeout}) async {
    final http.Response res;
    try {
      res = await call().timeout(timeout ?? this.timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.network);
    } on http.ClientException catch (e) {
      throw ApiException(ApiErrorKind.network, detail: e.message);
    } on ApiException {
      rethrow;
    } catch (e) {
      // SocketException, HandshakeException… (dart:io absent sur le web).
      throw ApiException(ApiErrorKind.network, detail: e.toString());
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return res;
    throw _error(res);
  }

  ApiException _error(http.Response res) {
    String? detail;
    String? code;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map) {
        code = body['code'] as String?;
        final d = body['detail'];
        if (d is Map) {
          code ??= d['code'] as String?;
          detail = d['message'] as String? ?? d.toString();
        } else if (d != null) {
          detail = d.toString();
        }
      }
    } catch (_) {}
    final kind = switch (res.statusCode) {
      429 => ApiErrorKind.rateLimited,
      503 => ApiErrorKind.unavailable,
      404 => ApiErrorKind.notFound,
      422 when code == 'consent_required' || (detail?.contains('consent_required') ?? false) =>
        ApiErrorKind.consentRequired,
      _ => ApiErrorKind.other,
    };
    return ApiException(kind, statusCode: res.statusCode, detail: detail ?? code);
  }

  Map<String, dynamic> _json(http.Response res) =>
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

  @override
  Future<List<Site>> sites() async {
    final res = await _send(() => _client.get(_uri('/public/sites')));
    return [for (final i in _json(res)['items'] as List) Site.fromJson(i as Map<String, dynamic>)];
  }

  @override
  Future<List<InformationItem>> information() async {
    final res = await _send(() => _client.get(_uri('/public/information')));
    return [
      for (final i in _json(res)['items'] as List)
        InformationItem.fromJson(i as Map<String, dynamic>)
    ];
  }

  @override
  Future<Menu> menus(Module module, String language) async {
    final res = await _send(() => _client
        .get(_uri('/public/menus', {'module': module.name, 'language': language})));
    return Menu.fromJson(_json(res));
  }

  @override
  Future<AskResult> askText(
      {required Module module,
      required String text,
      required String language,
      String? siteId}) async {
    final res = await _send(() => _client.post(
          _uri('/public/ask'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'module': module.name,
            'text': text,
            'language': language,
            'site_id': ?siteId,
          }),
        ));
    return AskResult.fromJson(_json(res));
  }

  @override
  Future<AskResult> askVoice(
      {required Module module,
      required VoiceClip clip,
      required String language,
      String? siteId,
      required bool voiceConsent}) async {
    // Le consentement est vérifié ici aussi : sans lui, rien ne part.
    if (!voiceConsent) throw const ApiException(ApiErrorKind.consentRequired);
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', _uri('/public/ask'))
        ..fields['module'] = module.name
        ..fields['language'] = language
        ..fields['voice_consent'] = 'true'
        ..files.add(http.MultipartFile.fromBytes('audio', clip.bytes,
            filename: clip.filename, contentType: MediaType.parse(clip.mimeType)));
      if (siteId != null) req.fields['site_id'] = siteId;
      return http.Response.fromStream(await _client.send(req));
    }, timeout: voiceTimeout);
    return AskResult.fromJson(_json(res));
  }

  @override
  Future<QuestionStatus> question(String questionId, String token) async {
    final res = await _send(() => _client.get(
        _uri('/public/questions/${Uri.encodeComponent(questionId)}', {'token': token})));
    return QuestionStatus.fromJson(_json(res));
  }

  @override
  Future<void> deleteQuestion(String questionId, String token) async {
    await _send(() => _client.delete(
        _uri('/public/questions/${Uri.encodeComponent(questionId)}', {'token': token})));
  }
}
