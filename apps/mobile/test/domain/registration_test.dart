import 'package:fanilo_mobile/data/repositories/local_repository.dart';
import 'package:fanilo_mobile/data/repositories/outbox_repository.dart';
import 'package:fanilo_mobile/domain/enums.dart';
import 'package:fanilo_mobile/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

const _identity = IdentityInput(displayName: 'Personne fictive');

ConsentInput _consent({
  Set<ConsentScope> scopes = const {ConsentScope.reny},
  ConsentMethod? method = ConsentMethod.written,
  String? version = 'INFO-DEMO-0.1',
  bool presented = true,
}) =>
    ConsentInput(
        scopes: scopes,
        method: method,
        informationVersion: version,
        informationPresented: presented);

void main() {
  group('Consentement obligatoire', () {
    test('chaque élément du consentement est requis', () {
      expect(_consent().isComplete, isTrue);
      expect(_consent(scopes: {}).isComplete, isFalse);
      expect(_consent(method: null).isComplete, isFalse);
      expect(_consent(version: ' ').isComplete, isFalse);
      expect(_consent(presented: false).isComplete, isFalse);
    });

    test('pas d\'identité sans consentement complet', () {
      expect(RegistrationDraft().canEnterIdentity, isFalse);
      expect(RegistrationDraft(consent: _consent(presented: false)).canEnterIdentity, isFalse);
      expect(RegistrationDraft(consent: _consent()).canEnterIdentity, isTrue);
    });

    test('validate() refuse un brouillon sans consentement', () {
      expect(() => RegistrationDraft(identity: _identity).validate(),
          throwsA(isA<ConsentRequiredException>()));
    });

    test('l\'enregistrement sans consentement n\'écrit rien en base', () async {
      final db = newTestDb();
      addTearDown(db.close);
      final repo = LocalRepository(db, OutboxRepository(db));

      await expectLater(
        repo.registerBeneficiary(
            RegistrationDraft(consent: _consent(method: null), identity: _identity), testUser),
        throwsA(isA<ConsentRequiredException>()),
      );
      expect(await db.select(db.beneficiaries).get(), isEmpty);
      expect(await db.select(db.beneficiaryIdentities).get(), isEmpty);
      expect(await db.select(db.consents).get(), isEmpty);
      expect(await db.select(db.outbox).get(), isEmpty);
    });

    test('enregistrement complet : identité séparée, consentements tracés', () async {
      final db = newTestDb();
      addTearDown(db.close);
      final repo = LocalRepository(db, OutboxRepository(db));

      final id = await repo.registerBeneficiary(
        RegistrationDraft(
          consent: _consent(scopes: {ConsentScope.reny, ConsentScope.reminders}),
          identity: const IdentityInput(displayName: '  Personne fictive ', phone: ' '),
        ),
        testUser,
      );

      final b = await db.select(db.beneficiaries).getSingle();
      expect(b.id, id);
      expect(b.siteId, testUser.siteId);
      expect(b.version, 0);
      final identity = await db.select(db.beneficiaryIdentities).getSingle();
      expect(identity.displayName, 'Personne fictive');
      expect(identity.phone, isNull);
      final consents = await db.select(db.consents).get();
      expect(consents.map((c) => c.scope).toSet(), {'reny', 'reminders'});
      expect(consents.every((c) => c.collectedByUserId == testUser.id), isTrue);
      expect(consents.every((c) => c.method == 'written'), isTrue);
      final outbox = await db.select(db.outbox).get();
      expect(outbox.map((o) => o.entity).toList(),
          ['beneficiary', 'consent', 'consent', 'beneficiary_identity']);
      // Le bénéficiaire ne contient aucun nom.
      expect(outbox.first.data.contains('Personne'), isFalse);
    });

    test('grossesse refusée sans consentement RENY actif', () async {
      final db = newTestDb();
      addTearDown(db.close);
      final repo = LocalRepository(db, OutboxRepository(db));
      final id = await repo.registerBeneficiary(
          RegistrationDraft(
              consent: _consent(scopes: {ConsentScope.reminders}), identity: _identity),
          testUser);

      await expectLater(repo.createPregnancy(beneficiaryId: id),
          throwsA(isA<NoActiveRenyConsentException>()));

      final id2 = await repo.registerBeneficiary(
          RegistrationDraft(consent: _consent(), identity: _identity), testUser);
      final consent = (await db.select(db.consents).get())
          .firstWhere((c) => c.beneficiaryId == id2);
      await repo.withdrawConsent(consent.id, testUser);
      await expectLater(repo.createPregnancy(beneficiaryId: id2),
          throwsA(isA<NoActiveRenyConsentException>()));
    });
  });
}
