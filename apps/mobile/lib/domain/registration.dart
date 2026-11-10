import 'enums.dart';

/// Consentement recueilli à l'étape 1 de l'enregistrement (F-01).
class ConsentInput {
  const ConsentInput({
    required this.scopes,
    required this.method,
    required this.informationVersions,
    required this.informationPresented,
  });

  final Set<ConsentScope> scopes;
  final ConsentMethod? method;

  /// Version de l'information présentée, **par portée** (servie par
  /// `GET /reference/consent-information`).
  final Map<ConsentScope, String> informationVersions;

  /// L'AC confirme avoir présenté l'information et recueilli l'accord.
  final bool informationPresented;

  /// Le consentement est complet : au moins une portée, une méthode, une
  /// version de l'information pour chaque portée et la confirmation de
  /// présentation.
  bool get isComplete =>
      scopes.isNotEmpty &&
      method != null &&
      scopes.every((s) => versionFor(s) != null) &&
      informationPresented;

  /// Version (non vide) de l'information présentée pour [scope].
  String? versionFor(ConsentScope scope) {
    final v = informationVersions[scope]?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  bool get coversReny => scopes.contains(ConsentScope.reny);
}

/// Identité (étape 2), stockée séparément du suivi.
class IdentityInput {
  const IdentityInput({required this.displayName, this.phone, this.village});
  final String displayName;
  final String? phone;
  final String? village;

  bool get isValid => displayName.trim().isNotEmpty;
}

/// Données de suivi pseudonymisées (sans nom).
class BeneficiaryInput {
  const BeneficiaryInput({this.birthYear, required this.preferredChannel});
  final int? birthYear;
  final PreferredChannel preferredChannel;
}

class ConsentRequiredException implements Exception {
  const ConsentRequiredException();
  @override
  String toString() =>
      'Le consentement doit être recueilli avant tout enregistrement.';
}

enum RegistrationError { nameRequired, invalidBirthYear }

class InvalidRegistrationException implements Exception {
  const InvalidRegistrationException(this.error, this.message);
  final RegistrationError error;
  final String message;
  @override
  String toString() => message;
}

/// Brouillon d'enregistrement : le consentement est obligatoire **avant**
/// la saisie de l'identité et avant toute écriture locale.
class RegistrationDraft {
  RegistrationDraft({this.consent, this.identity, this.beneficiary});

  ConsentInput? consent;
  IdentityInput? identity;
  BeneficiaryInput? beneficiary;

  bool get canEnterIdentity => consent?.isComplete ?? false;

  /// Vérifie le brouillon ; lève une exception si le consentement manque.
  void validate() {
    final c = consent;
    if (c == null || !c.isComplete) throw const ConsentRequiredException();
    final id = identity;
    if (id == null || !id.isValid) {
      throw const InvalidRegistrationException(
          RegistrationError.nameRequired, 'Le nom est obligatoire.');
    }
    final by = beneficiary?.birthYear;
    if (by != null && (by < 1900 || by > DateTime.now().year)) {
      throw const InvalidRegistrationException(
          RegistrationError.invalidBirthYear, 'Année de naissance invalide.');
    }
  }
}
