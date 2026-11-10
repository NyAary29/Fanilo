import 'dart:convert';

import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/api/public_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _askJson = {
  'question_id': 'q1',
  'transcript': 'mandeha ra aho',
  'transcript_needs_review': false,
  'outcome': 'fallback',
  'actions': ['transfer_counselor'],
  'content': {
    'code': 'MSG_DEMO_TRANSFER_COUNSELOR',
    'title': '[DÉMO] Transmise',
    'body': '[DÉMO] Corps',
    'audio_url': null,
    'status': 'demo',
  },
  'urgent': true,
  'follow_up': {'token': 'secret-token-0123456789', 'status': 'pending'},
  'is_demo': true,
  'disclaimer': 'FANILO ne remplace pas un professionnel de santé.',
};

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final base = Uri.parse('http://api.test:8000');

  test('sites, information et menus sont décodés', () async {
    final api = HttpPublicApi(base, client: MockClient((req) async {
      switch (req.url.path) {
        case '/public/sites':
          return _json({
            'items': [
              {'id': 's1', 'name': 'CSB II Démo', 'district': 'D', 'region': 'R'}
            ]
          });
        case '/public/information':
          return _json({
            'items': [
              {'scope': 'voice_processing', 'version': 'v1', 'status': 'demo', 'summary_fr': 'FR', 'summary_mg': null}
            ]
          });
        case '/public/menus':
          expect(req.url.queryParameters, {'module': 'tanora', 'language': 'mg'});
          return _json({
            'config_id': 'c',
            'version': '0.1.0',
            'is_demo': true,
            'module': 'tanora',
            'items': [
              {'key': 1, 'code': 'MSG_X', 'title': 'Règles', 'body': 'Corps', 'audio_url': '/a.mp3', 'status': 'demo'}
            ]
          });
      }
      return http.Response('', 404);
    }));
    final sites = await api.sites();
    expect(sites.single.name, 'CSB II Démo');
    expect(sites.single.place, 'D · R');
    final info = await api.information();
    expect(info.single.summary('mg'), 'FR', reason: 'repli sur le français');
    final menu = await api.menus(Module.tanora, 'mg');
    expect(menu.isDemo, isTrue);
    expect(menu.items.single.key, 1);
    expect(menu.items.single.content.audioUrl, '/a.mp3');
  });

  test('askText envoie du JSON et décode urgent + follow_up (fallback suspecté)', () async {
    late Map<String, dynamic> sent;
    final api = HttpPublicApi(base, client: MockClient((req) async {
      expect(req.method, 'POST');
      expect(req.url.path, '/public/ask');
      expect(req.headers['content-type'], startsWith('application/json'));
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return _json(_askJson);
    }));
    final r = await api.askText(module: Module.reny, text: 'mandeha ra aho', language: 'mg', siteId: 's1');
    expect(sent, {'module': 'reny', 'text': 'mandeha ra aho', 'language': 'mg', 'site_id': 's1'});
    expect(r.urgent, isTrue);
    expect(r.outcome, 'fallback');
    expect(r.followUp!.token, 'secret-token-0123456789');
    expect(r.showDemoBanner, isTrue);
    expect(r.content!.code, 'MSG_DEMO_TRANSFER_COUNSELOR');
  });

  test('askText sans site : pas de site_id', () async {
    late Map<String, dynamic> sent;
    final api = HttpPublicApi(base, client: MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return _json({..._askJson, 'follow_up': null, 'content': null, 'urgent': false});
    }));
    final r = await api.askText(module: Module.tanora, text: 'x', language: 'fr');
    expect(sent.containsKey('site_id'), isFalse);
    expect(r.followUp, isNull);
    expect(r.content, isNull);
  });

  test('askVoice : multipart avec voice_consent=true et type audio', () async {
    final api = HttpPublicApi(base, client: MockClient((req) async {
      final ct = req.headers['content-type']!;
      expect(ct, startsWith('multipart/form-data'));
      final body = latin1.decode(req.bodyBytes);
      expect(body, contains('name="voice_consent"\r\n\r\ntrue'));
      expect(body, contains('name="module"\r\n\r\ntanora'));
      expect(body, contains('name="audio"; filename="q.m4a"'));
      expect(body, contains('content-type: audio/mp4'));
      return _json(_askJson);
    }));
    final r = await api.askVoice(
        module: Module.tanora,
        clip: const VoiceClip(bytes: [1, 2, 3], filename: 'q.m4a', mimeType: 'audio/mp4'),
        language: 'mg',
        voiceConsent: true);
    expect(r.questionId, 'q1');
  });

  test('délai d\'attente de la question vocale ≥ 60 s (transcription sur CPU)', () {
    expect(HttpPublicApi(base).voiceTimeout, greaterThanOrEqualTo(const Duration(seconds: 60)));
  });

  test('askVoice sans consentement : rien ne part', () async {
    var calls = 0;
    final api = HttpPublicApi(base, client: MockClient((req) async {
      calls++;
      return _json(_askJson);
    }));
    await expectLater(
        api.askVoice(
            module: Module.reny,
            clip: const VoiceClip(bytes: [1], filename: 'q.wav', mimeType: 'audio/wav'),
            language: 'mg',
            voiceConsent: false),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.consentRequired)));
    expect(calls, 0);
  });

  group('erreurs', () {
    Future<ApiErrorKind> kindFor(http.Response res) async {
      final api = HttpPublicApi(base, client: MockClient((_) async => res));
      try {
        await api.askText(module: Module.reny, text: 'x', language: 'mg');
      } on ApiException catch (e) {
        return e.kind;
      }
      fail('pas d\'exception');
    }

    test('429', () async => expect(await kindFor(_json({'detail': 'trop'}, 429)), ApiErrorKind.rateLimited));
    test('422 consent_required', () async => expect(
        await kindFor(_json({'detail': {'code': 'consent_required', 'message': 'Accord'}}, 422)),
        ApiErrorKind.consentRequired));
    test('422 autre', () async => expect(await kindFor(_json({'detail': []}, 422)), ApiErrorKind.other));
    test('503', () async => expect(await kindFor(_json({'detail': 'x'}, 503)), ApiErrorKind.unavailable));
    test('réseau', () async {
      final api = HttpPublicApi(base, client: MockClient((_) async => throw http.ClientException('down')));
      await expectLater(api.sites(),
          throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.network)));
    });
  });

  test('orientation : présente ou nulle', () async {
    final api = HttpPublicApi(base, client: MockClient((req) async {
      final withO = req.url.path.endsWith('q1');
      return _json({
        'question_id': withO ? 'q1' : 'q2',
        'module': 'reny',
        'status': 'answered',
        'answer': 'Mandehana',
        'answered_at': '2026-11-10T10:00:00Z',
        'orientation': withO
            ? {'name': 'CHRR Bongolava', 'kind': 'reference_facility', 'district': 'Tsiroanomandidy', 'region': 'Bongolava'}
            : null,
        'triage': withO ? 'urgent' : 'info',
        'follow_up_code': withO ? 'K7-42' : null,
        'follow_up_status': withO ? 'expected' : null,
      });
    }));
    final a = await api.question('q1', 'tok-0123456789abcdef');
    expect(a.triage, 'urgent');
    expect(a.followUpCode, 'K7-42');
    expect(a.followUpStatus, 'expected');
    expect(a.orientation!.name, 'CHRR Bongolava');
    expect(a.orientation!.isReferenceFacility, isTrue);
    expect(a.orientation!.place, 'Tsiroanomandidy · Bongolava');
    final b = await api.question('q2', 'tok-0123456789abcdef');
    expect(b.orientation, isNull);
    expect(b.triage, 'info');
    expect(b.followUpCode, isNull);
    expect(b.followUpStatus, isNull);
  });

  test('question et deleteQuestion passent le jeton en paramètre', () async {
    final seen = <String>[];
    final api = HttpPublicApi(base, client: MockClient((req) async {
      seen.add('${req.method} ${req.url.path} ${req.url.queryParameters['token']}');
      if (req.method == 'DELETE') return http.Response('', 204);
      if (req.url.queryParameters['token'] == 'bad-token-0123456789') {
        return _json({'detail': 'Introuvable'}, 404);
      }
      return _json({
        'question_id': 'q1',
        'module': 'tanora',
        'status': 'answered',
        'answer': 'Réponse',
        'answered_at': '2026-11-09T10:00:00Z',
      });
    }));
    final s = await api.question('q1', 'tok-0123456789abcdef');
    expect(s.isAnswered, isTrue);
    expect(s.answer, 'Réponse');
    expect(s.module, Module.tanora);
    await api.deleteQuestion('q1', 'tok-0123456789abcdef');
    await expectLater(api.question('q1', 'bad-token-0123456789'),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.notFound)));
    expect(seen.take(2), [
      'GET /public/questions/q1 tok-0123456789abcdef',
      'DELETE /public/questions/q1 tok-0123456789abcdef',
    ]);
  });
}
