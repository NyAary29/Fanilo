import 'package:fanilo_femmes/data/api/models.dart';
import 'package:fanilo_femmes/data/local/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('un ticket ne garde que id, jeton, module et date', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    await store.addTicket(Ticket(
        questionId: 'q1', token: 'tok-1', module: Module.tanora, createdAt: DateTime.utc(2026, 11, 9)));
    final raw = prefs.getString('fanilo.tickets.v1')!;
    expect(raw,
        '[{"question_id":"q1","token":"tok-1","module":"tanora","created_at":"2026-11-09T00:00:00.000Z"}]');
    expect(store.tickets.single.module, Module.tanora);
  });

  test('ajout, tri, suppression et effacement', () async {
    final store = LocalStore(await SharedPreferences.getInstance());
    await store.addTicket(Ticket(questionId: 'a', token: 't', module: Module.reny, createdAt: DateTime.utc(2026, 1, 1)));
    await store.addTicket(Ticket(questionId: 'b', token: 't', module: Module.reny, createdAt: DateTime.utc(2026, 2, 1)));
    await store.addTicket(Ticket(questionId: 'a', token: 't2', module: Module.reny, createdAt: DateTime.utc(2026, 1, 1)));
    expect(store.tickets.map((t) => t.questionId), ['b', 'a']);
    expect(store.tickets.last.token, 't2');
    await store.removeTicket('b');
    expect(store.tickets.map((t) => t.questionId), ['a']);
    await store.clearTickets();
    expect(store.tickets, isEmpty);
  });

  test('consentement, site, langue ; seules les clés prévues sont écrites', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = LocalStore(prefs);
    expect(store.locale, 'mg', reason: 'malgache par défaut');
    expect(store.voiceConsent, isNull);
    await store.setVoiceConsent(VoiceConsent(version: 'v1', acceptedAt: DateTime.utc(2026)));
    await store.setSite(const SavedSite('s1', 'CSB'));
    await store.setLocale('fr');
    await store.setOnboarded();
    await store.addTicket(Ticket(questionId: 'q9', token: 't', module: Module.reny, createdAt: DateTime.utc(2026)));
    await store.markRead(['q9']);
    expect(store.readAnswers, {'q9'});
    expect(prefs.getStringList('fanilo.read_answers.v1'), ['q9'], reason: 'identifiants seulement');
    expect(store.voiceConsent!.version, 'v1');
    expect(store.site!.name, 'CSB');
    expect(prefs.getKeys().difference(LocalStore.allowedKeys), isEmpty);
    await store.setVoiceConsent(null);
    await store.setSite(null);
    expect(store.voiceConsent, isNull);
    expect(store.site, isNull);
  });

  test('données corrompues : liste vide', () async {
    SharedPreferences.setMockInitialValues({'fanilo.tickets.v1': 'not json'});
    final store = LocalStore(await SharedPreferences.getInstance());
    expect(store.tickets, isEmpty);
  });
}
