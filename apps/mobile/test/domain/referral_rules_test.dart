import 'package:fanilo_mobile/data/local/entity_store.dart';
import 'package:fanilo_mobile/data/repositories/local_repository.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/domain/referral_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  group('ReferralRules (contrat §7)', () {
    const allowed = {
      ReferralStatus.proposed: {ReferralStatus.accepted, ReferralStatus.notCompleted},
      ReferralStatus.accepted: {
        ReferralStatus.arrived,
        ReferralStatus.transferred,
        ReferralStatus.notCompleted
      },
      ReferralStatus.transferred: {ReferralStatus.arrived, ReferralStatus.notCompleted},
      ReferralStatus.arrived: <ReferralStatus>{},
      ReferralStatus.notCompleted: <ReferralStatus>{},
    };

    test('matrice complète des transitions', () {
      for (final from in ReferralStatus.values) {
        for (final to in ReferralStatus.values) {
          expect(ReferralRules.canTransition(from, to), allowed[from]!.contains(to),
              reason: '${from.wire} → ${to.wire}');
        }
      }
    });

    test('non aboutie exige un motif', () {
      expect(
          () => ReferralRules.validate(ReferralStatus.proposed, ReferralStatus.notCompleted),
          throwsA(isA<ReferralTransitionException>()));
      expect(
          () => ReferralRules.validate(ReferralStatus.proposed, ReferralStatus.notCompleted,
              reason: '  '),
          throwsA(isA<ReferralTransitionException>()));
      ReferralRules.validate(ReferralStatus.proposed, ReferralStatus.notCompleted,
          reason: 'Motif fictif');
    });
  });

  group('LocalRepository.transitionReferral', () {
    test('refuse une transition interdite sans rien écrire', () async {
      final db = newTestDb();
      addTearDown(db.close);
      final repo = LocalRepository(db, OutboxRepository(db));
      await EntityStore(db).applyServer(SyncEntity.referral, 'r-1', 1, null,
          {'beneficiary_id': 'b-1', 'to_site_id': 's-1', 'status': 'arrived'});

      await expectLater(repo.transitionReferral('r-1', ReferralStatus.accepted),
          throwsA(isA<ReferralTransitionException>()));
      expect((await db.select(db.referrals).getSingle()).status, 'arrived');
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('transition autorisée : ligne locale et outbox mises à jour', () async {
      final db = newTestDb();
      addTearDown(db.close);
      final repo = LocalRepository(db, OutboxRepository(db));
      await EntityStore(db).applyServer(SyncEntity.referral, 'r-1', 4, null,
          {'beneficiary_id': 'b-1', 'to_site_id': 's-1', 'status': 'accepted'});

      await repo.transitionReferral('r-1', ReferralStatus.transferred);

      expect((await db.select(db.referrals).getSingle()).status, 'transferred');
      final entry = await db.select(db.outbox).getSingle();
      expect(entry.entity, 'referral');
      expect(entry.baseVersion, 4);
    });
  });
}
