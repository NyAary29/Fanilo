import 'package:fanilo_femmes/data/api/fake_public_api.dart';
import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/audio/voice.dart';
import 'package:fanilo_femmes/data/local/local_store.dart';
import 'package:fanilo_femmes/ui/app.dart';
import 'package:fanilo_femmes/ui/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeRecorder implements VoiceRecorder {
  bool permission = true;
  int starts = 0;
  int permissionRequests = 0;
  bool recording = false;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> start() async {
    starts++;
    recording = true;
  }

  @override
  Future<VoiceClip?> stop() async {
    recording = false;
    return const VoiceClip(bytes: [1, 2, 3, 4], filename: 'q.m4a', mimeType: 'audio/mp4');
  }

  @override
  Future<void> cancel() async => recording = false;

  @override
  Future<void> dispose() async {}
}

class FakePlayback implements AudioPlayback {
  final played = <Uri>[];
  @override
  Future<void> play(Uri url) async => played.add(url);
  @override
  Future<void> stop() async {}
}

class TestEnv {
  TestEnv._(this.prefs, this.api, this.recorder);
  final SharedPreferences prefs;
  final FakePublicApi api;
  final FakeRecorder recorder;
  late LocalStore store = LocalStore(prefs);

  static Future<TestEnv> create({
    bool onboarded = true,
    bool voiceConsent = false,
    String locale = 'fr',
    Map<String, Object> extra = const {},
    int? answerAfterPolls,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (onboarded) 'fanilo.onboarded.v1': true,
      'fanilo.locale.v1': locale,
      if (voiceConsent) 'fanilo.voice_consent.version.v1': 'demo-0.1',
      if (voiceConsent) 'fanilo.voice_consent.at.v1': '2026-11-09T08:00:00.000Z',
      ...extra,
    });
    final prefs = await SharedPreferences.getInstance();
    return TestEnv._(prefs, FakePublicApi(answerAfterPolls: answerAfterPolls), FakeRecorder());
  }

  Widget app() => ProviderScope(
        overrides: [
          storeProvider.overrideWithValue(store),
          apiProvider.overrideWithValue(api),
          recorderProvider.overrideWithValue(recorder),
          playbackProvider.overrideWithValue(FakePlayback()),
        ],
        child: const FaniloFemmesApp(),
      );

  /// Tout ce qui est écrit sur le téléphone, en texte.
  String dump() => {for (final k in prefs.getKeys()) k: prefs.get(k)}.toString();
}

void phone(WidgetTester tester, {double height = 851}) {
  tester.view.physicalSize = Size(393 * 2.75, height * 2.75);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}
