// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'FANILO';

  @override
  String get disclaimer => 'FANILO ne remplace pas un professionnel de santé.';

  @override
  String get demoBanner => 'DÉMO — liste non validée cliniquement';

  @override
  String get demoData => 'Charger des données de démonstration (fictives)';

  @override
  String get demoDataLoaded => 'Données de démonstration chargées.';

  @override
  String get errorGeneric => 'Une erreur est survenue.';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get next => 'Continuer';

  @override
  String get back => 'Retour';

  @override
  String get save => 'Enregistrer';

  @override
  String get loginTitle => 'Connexion';

  @override
  String get loginField => 'Identifiant';

  @override
  String get passwordField => 'Mot de passe';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get loginErrorCredentials => 'Identifiant ou mot de passe incorrect.';

  @override
  String get loginErrorOffline => 'Pas de connexion. La première connexion demande le réseau.';

  @override
  String get loginErrorDifferentUser => 'Un autre compte est ouvert sur ce téléphone. Déconnectez-le d\'abord.';

  @override
  String get loginErrorGeneric => 'Connexion impossible. Réessayez.';

  @override
  String get homeTitle => 'Accueil';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get syncRunning => 'Synchronisation…';

  @override
  String syncLast(String when) {
    return 'Dernière synchro : $when';
  }

  @override
  String get syncNever => 'Jamais synchronisé';

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: '1 modification en attente',
      zero: 'Rien en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncErrorOffline => 'Hors ligne. Les données restent sur le téléphone.';

  @override
  String get syncErrorSession => 'Reconnectez-vous pour synchroniser.';

  @override
  String get syncErrorServer => 'Serveur indisponible. Nouvel essai plus tard.';

  @override
  String get syncDone => 'Synchronisation terminée.';

  @override
  String get online => 'En ligne';

  @override
  String get offline => 'Hors ligne';

  @override
  String rejectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count envois refusés, à vérifier',
      one: '1 envoi refusé, à vérifier',
    );
    return '$_temp0';
  }

  @override
  String conflictsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflits à revoir',
      one: '1 conflit à revoir',
    );
    return '$_temp0';
  }

  @override
  String get upcomingAnc => 'CPN à venir (7 jours)';

  @override
  String get noUpcomingAnc => 'Aucune CPN prévue.';

  @override
  String get overdue => 'En retard';

  @override
  String openAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alertes ouvertes',
      one: '1 alerte ouverte',
      zero: 'Aucune alerte ouverte',
    );
    return '$_temp0';
  }

  @override
  String get menuBeneficiaries => 'Bénéficiaires';

  @override
  String get menuRegister => 'Enregistrer';

  @override
  String get menuSigns => 'Signaler des signes';

  @override
  String get menuReferrals => 'Références';

  @override
  String get menuAlerts => 'Alertes';

  @override
  String get menuConflicts => 'Conflits';

  @override
  String get logout => 'Se déconnecter';

  @override
  String logoutConfirmPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications ne sont pas encore envoyées et seront perdues.',
      one: '1 modification n\'est pas encore envoyée et sera perdue.',
    );
    return '$_temp0 Se déconnecter ?';
  }

  @override
  String get logoutConfirm => 'Les données de ce téléphone seront effacées. Se déconnecter ?';

  @override
  String get reauthBanner => 'Session expirée. Reconnectez-vous pour synchroniser.';

  @override
  String get reauthButton => 'Se reconnecter';

  @override
  String get beneficiariesTitle => 'Bénéficiaires';

  @override
  String get noBeneficiaries => 'Aucun bénéficiaire.';

  @override
  String get codePending => 'Code en attente';

  @override
  String get searchHint => 'Rechercher un nom ou un code';

  @override
  String get registerTitle => 'Enregistrement';

  @override
  String get stepConsent => '1. Consentement';

  @override
  String get stepIdentity => '2. Identité';

  @override
  String get consentIntro => 'Présentez l\'information. Recueillez l\'accord avant toute saisie.';

  @override
  String get consentScopes => 'Portée du consentement';

  @override
  String get scopeReny => 'Suivi de grossesse (RENY)';

  @override
  String get scopeTanora => 'Jeunes (TANORA)';

  @override
  String get scopeReminders => 'Rappels';

  @override
  String get scopeVoice => 'Traitement de la voix';

  @override
  String get consentMethod => 'Méthode';

  @override
  String get methodOral => 'Orale';

  @override
  String get methodWritten => 'Écrite';

  @override
  String get infoVersion => 'Version de l\'information présentée';

  @override
  String get infoPresented => 'J\'ai présenté l\'information. La personne est d\'accord.';

  @override
  String get consentIncomplete => 'Consentement obligatoire avant de continuer.';

  @override
  String get identityConfidential => 'Identité (confidentielle)';

  @override
  String get displayName => 'Nom';

  @override
  String get phone => 'Téléphone (facultatif)';

  @override
  String get village => 'Village (facultatif)';

  @override
  String get followUp => 'Suivi (sans nom)';

  @override
  String get birthYear => 'Année de naissance (facultatif)';

  @override
  String get preferredChannel => 'Canal préféré';

  @override
  String get channelSms => 'SMS';

  @override
  String get channelIvr => 'Message vocal';

  @override
  String get channelAcVisit => 'Visite de l\'AC';

  @override
  String get channelNone => 'Aucun';

  @override
  String get registered => 'Bénéficiaire enregistré.';

  @override
  String get nameRequired => 'Le nom est obligatoire.';

  @override
  String get invalidBirthYear => 'Année invalide.';

  @override
  String get beneficiaryTitle => 'Bénéficiaire';

  @override
  String get consentsTitle => 'Consentements';

  @override
  String get consentActive => 'Actif';

  @override
  String get consentWithdrawn => 'Retiré';

  @override
  String get withdraw => 'Retirer';

  @override
  String get withdrawConfirm => 'Retirer ce consentement ? Les rappels liés seront arrêtés.';

  @override
  String get pendingSync => 'En attente d\'envoi';

  @override
  String get pregnancyTitle => 'Grossesse';

  @override
  String get noPregnancy => 'Aucune grossesse déclarée.';

  @override
  String get declarePregnancy => 'Déclarer une grossesse';

  @override
  String get lmpDate => 'Date des dernières règles (facultatif)';

  @override
  String get pickDate => 'Choisir une date';

  @override
  String get confirmedBy => 'Dates confirmées par';

  @override
  String get confirmedAc => 'Déclaration (AC)';

  @override
  String get confirmedHealthWorker => 'Agent de santé';

  @override
  String get confirmedUltrasound => 'Échographie';

  @override
  String get needRenyConsent => 'Consentement RENY actif requis.';

  @override
  String get pregnancyActive => 'En cours';

  @override
  String get pregnancyDelivered => 'Accouchement';

  @override
  String get pregnancyEnded => 'Terminée';

  @override
  String get pregnancyTransferred => 'Transférée';

  @override
  String get ancCalendar => 'Calendrier CPN';

  @override
  String get ancWaiting => 'Le calendrier arrivera après la synchronisation.';

  @override
  String ancVisit(int n, String date) {
    return 'CPN $n — $date';
  }

  @override
  String get ancPlanned => 'Prévue';

  @override
  String get ancDone => 'Réalisée';

  @override
  String get ancMissed => 'Manquée';

  @override
  String get ancCancelled => 'Annulée';

  @override
  String get markDone => 'Réalisée';

  @override
  String get markMissed => 'Manquée';

  @override
  String get referralsTitle => 'Références';

  @override
  String get noReferrals => 'Aucune référence.';

  @override
  String get referralProposed => 'Proposée';

  @override
  String get referralAccepted => 'Acceptée';

  @override
  String get referralArrived => 'Arrivée';

  @override
  String get referralTransferred => 'Transférée';

  @override
  String get referralNotCompleted => 'Non aboutie';

  @override
  String get changeStatus => 'Changer le statut';

  @override
  String get reasonRequired => 'Motif (obligatoire)';

  @override
  String get outcomeNote => 'Note (facultatif)';

  @override
  String get noTransition => 'Aucune action possible.';

  @override
  String get alertsTitle => 'Alertes';

  @override
  String get noAlerts => 'Aucune alerte.';

  @override
  String get alertsReadOnly => 'Lecture seule. Mise à jour à chaque synchronisation.';

  @override
  String get alertOpen => 'Ouverte';

  @override
  String get alertAcknowledged => 'Accusé de réception';

  @override
  String get alertResolved => 'Résolue';

  @override
  String get alertEscalated => 'Escaladée';

  @override
  String get alertCancelled => 'Annulée';

  @override
  String get severityCritical => 'Critique';

  @override
  String get severityUrgent => 'Urgente';

  @override
  String get severityRoutine => 'Routine';

  @override
  String alertDue(String date) {
    return 'Échéance : $date';
  }

  @override
  String get demoTag => 'DÉMO';

  @override
  String get signsTitle => 'Signaler des signes';

  @override
  String get signsIntro => 'Cochez les signes observés.';

  @override
  String get signsBeneficiary => 'Bénéficiaire (facultatif)';

  @override
  String get noneSelected => 'Aucun';

  @override
  String get signsSend => 'Envoyer';

  @override
  String get signsSelectOne => 'Cochez au moins un signe.';

  @override
  String get signsOffline => 'Pas de connexion. Contactez directement le CSB selon la procédure locale.';

  @override
  String get signsError => 'Envoi impossible. Contactez directement le CSB selon la procédure locale.';

  @override
  String get signsResultTitle => 'Orientation';

  @override
  String get actionReferCsb => 'Orienter vers le CSB';

  @override
  String get actionReferAdvisor => 'Transmis au conseiller';

  @override
  String actionOther(String code) {
    return 'Orientation : $code';
  }

  @override
  String get alertCreated => 'Alerte transmise. En attente d\'accusé de réception.';

  @override
  String get fallbackOutcome => 'Transmis au conseiller pour avis.';

  @override
  String get demoContent => 'Contenu de démonstration';

  @override
  String get newReport => 'Nouveau signalement';

  @override
  String get conflictsTitle => 'Conflits de synchronisation';

  @override
  String get noConflicts => 'Aucun conflit.';

  @override
  String get conflictExplain => 'La version du serveur a été gardée. Votre modification est conservée ici.';

  @override
  String get conflictLocal => 'Votre version';

  @override
  String get conflictServer => 'Version du serveur';

  @override
  String get keepServer => 'Garder le serveur';

  @override
  String get reapplyLocal => 'Renvoyer ma version';

  @override
  String get rejectedTitle => 'Envois refusés';

  @override
  String get retry => 'Réessayer';

  @override
  String get discard => 'Abandonner';

  @override
  String get entityBeneficiary => 'Bénéficiaire';

  @override
  String get entityIdentity => 'Identité';

  @override
  String get entityConsent => 'Consentement';

  @override
  String get entityPregnancy => 'Grossesse';

  @override
  String get entityAncVisit => 'CPN';

  @override
  String get entityReferral => 'Référence';

  @override
  String get entityAlert => 'Alerte';
}
