import 'package:fanilo_mobile/domain/follow_up.dart';
import 'package:fanilo_mobile/domain/reference_data.dart';
import 'package:flutter_test/flutter_test.dart';

AncSlot slot(int seq, String date, String status) =>
    AncSlot(id: 'v$seq', sequence: seq, scheduledDate: date, status: status);

void main() {
  const today = '2026-11-09';

  group('« À jour » / « À suivre »', () {
    test('CPN à venir seulement : à jour, prochaine CPN repérée', () {
      final a = assessFollowUp(visits: [
        slot(1, '2026-10-01', 'done'),
        slot(2, '2026-11-16', 'planned'),
        slot(3, '2026-12-14', 'planned'),
      ], hasOpenAlert: false, today: today);
      expect(a.status, FollowUpStatus.upToDate);
      expect(a.next!.sequence, 2);
      expect(a.overdue, isNull);
      expect(a.dueOn(today), isNull);
    });

    test('CPN prévue dont la date est passée : à suivre (en retard)', () {
      final a = assessFollowUp(visits: [
        slot(1, '2026-11-02', 'planned'),
        slot(2, '2026-12-01', 'planned'),
      ], hasOpenAlert: false, today: today);
      expect(a.status, FollowUpStatus.toFollow);
      expect(a.reasons, {FollowUpReason.overdueAnc});
      expect(a.overdue!.sequence, 1);
      expect(a.next!.sequence, 2);
      expect(a.dueOn(today)!.sequence, 1);
    });

    test('CPN du jour : due pendant la visite, pas en retard', () {
      final a = assessFollowUp(
          visits: [slot(1, today, 'planned')], hasOpenAlert: false, today: today);
      expect(a.status, FollowUpStatus.upToDate);
      expect(a.dueOn(today)!.sequence, 1);
    });

    test('CPN manquée : à suivre, sauf si une CPN suivante est réalisée', () {
      final missed = assessFollowUp(visits: [
        slot(1, '2026-10-01', 'missed'),
        slot(2, '2026-11-20', 'planned'),
      ], hasOpenAlert: false, today: today);
      expect(missed.reasons, {FollowUpReason.missedAnc});

      final caughtUp = assessFollowUp(visits: [
        slot(1, '2026-09-01', 'missed'),
        slot(2, '2026-10-01', 'done'),
      ], hasOpenAlert: false, today: today);
      expect(caughtUp.status, FollowUpStatus.upToDate);
    });

    test('alerte ouverte : à suivre, même sans CPN', () {
      final a = assessFollowUp(visits: const [], hasOpenAlert: true, today: today);
      expect(a.reasons, {FollowUpReason.openAlert});
    });

    test('alerte en attente d\'accusé de réception : open et escalated seulement', () {
      expect(isAwaitingAcknowledgement('open'), isTrue);
      expect(isAwaitingAcknowledgement('escalated'), isTrue);
      expect(isAwaitingAcknowledgement('acknowledged'), isFalse);
      expect(isAwaitingAcknowledgement('resolved'), isFalse);
    });
  });

  test('écart en jours entre deux dates du serveur', () {
    expect(daysFrom(today, '2026-11-16'), 7);
    expect(daysFrom(today, '2026-11-02'), -7);
    expect(daysFrom(today, 'n/a'), isNull);
  });

  test('mois de grossesse : affichage seulement, null si date inconnue ou incohérente', () {
    expect(approxPregnancyMonths('2026-08-05', today), 3);
    expect(approxPregnancyMonths('2026-10-30', today), 0);
    expect(approxPregnancyMonths(null, today), isNull);
    expect(approxPregnancyMonths('2026-12-01', today), isNull, reason: 'future');
    expect(approxPregnancyMonths('2025-01-01', today), isNull, reason: '> 320 jours');
  });

  test('âge et initiales', () {
    expect(approxAge(2002, 2026), 24);
    expect(approxAge(null, 2026), isNull);
    expect(approxAge(2030, 2026), isNull);
    expect(initialsOf('Rasoarivelo Marie'), 'RM');
    expect(initialsOf('  hanta '), 'H');
    expect(initialsOf(null), '?');
  });

  group('contenus publiés', () {
    PublishedContents parse(List<Map<String, dynamic>> items) =>
        PublishedContents.fromJson({'items': items, 'total': items.length});
    Map<String, dynamic> item(String code, String module, String lang,
            {String status = 'validated', String body = 'texte'}) =>
        {'code': code, 'module': module, 'language': lang, 'title': code, 'body': body, 'status': status};

    test('module + common, français de préférence, statuts non publiés ignorés', () {
      final c = parse([
        item('MSG_A', 'reny', 'mg'),
        item('MSG_A', 'reny', 'fr'),
        item('MSG_B', 'common', 'mg'),
        item('MSG_C', 'tanora', 'fr'),
        item('MSG_D', 'reny', 'fr', status: 'draft'),
        item('MSG_E', 'reny', 'fr', body: ' '),
      ]);
      final reny = c.forModule('reny');
      expect(reny.map((x) => x.code), ['MSG_A', 'MSG_B']);
      expect(reny.first.language, 'fr');
      expect(reny.last.language, 'mg', reason: 'repli sur une autre langue');
      expect(c.anyDemo, isFalse);
    });

    test('contenu demo signalé', () {
      expect(parse([item('MSG_A', 'reny', 'fr', status: 'demo')]).anyDemo, isTrue);
    });
  });
}
