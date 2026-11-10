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
  String get loginErrorOffline =>
      'Pas de connexion. La première connexion demande le réseau.';

  @override
  String get loginErrorDifferentUser =>
      'Un autre compte est ouvert sur ce téléphone. Déconnectez-le d\'abord.';

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
  String get syncErrorOffline =>
      'Hors ligne. Les données restent sur le téléphone.';

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
      other:
          '$count modifications ne sont pas encore envoyées et seront perdues.',
      one: '1 modification n\'est pas encore envoyée et sera perdue.',
    );
    return '$_temp0 Se déconnecter ?';
  }

  @override
  String get logoutConfirm =>
      'Les données de ce téléphone seront effacées. Se déconnecter ?';

  @override
  String get reauthBanner =>
      'Session expirée. Reconnectez-vous pour synchroniser.';

  @override
  String get reauthButton => 'Se reconnecter';

  @override
  String get noBeneficiaries =>
      'Aucune patiente. Touchez « Nouvelle patiente ».';

  @override
  String get codePending => 'Code en attente';

  @override
  String get registerTitle => 'Nouvelle patiente';

  @override
  String get stepConsent => 'Consentement';

  @override
  String get stepIdentity => 'Identité';

  @override
  String get consentIntro =>
      'Présentez l\'information. Recueillez l\'accord avant toute saisie.';

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
  String infoVersionOf(String version) {
    return 'Information version $version';
  }

  @override
  String get consentInfoMissing =>
      'Information de consentement non disponible. Connectez-vous au réseau et synchronisez une première fois.';

  @override
  String get consentInfoDemo =>
      'DÉMO — information de consentement non validée';

  @override
  String get consentScopeUnavailable =>
      'Information non disponible pour cette portée.';

  @override
  String get infoPresented =>
      'J\'ai présenté l\'information. La personne est d\'accord.';

  @override
  String get consentIncomplete =>
      'Consentement obligatoire avant de continuer.';

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
  String get registered => 'Patiente enregistrée.';

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
  String get withdrawConfirm =>
      'Retirer ce consentement ? Les rappels liés seront arrêtés.';

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
  String get ancNeedsLmp =>
      'Pas de calendrier CPN : le serveur le calcule à partir de la date des dernières règles (ou du terme prévu). Renseignez-la avec « Dates de la grossesse ».';

  @override
  String get editPregnancyDates => 'Dates de la grossesse';

  @override
  String get dueDate => 'Date prévue d\'accouchement (facultatif, si connue)';

  @override
  String get clearDate => 'Effacer la date';

  @override
  String get datesSaved =>
      'Dates enregistrées. Le calendrier viendra du serveur.';

  @override
  String get datesLmpInFuture =>
      'La date des dernières règles ne peut pas être dans le futur.';

  @override
  String get datesLmpTooOld => 'Date des dernières règles trop ancienne.';

  @override
  String get datesDueBeforeLmp =>
      'La date prévue doit suivre les dernières règles.';

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
  String get referralNew => 'Nouvelle référence';

  @override
  String get referralRefer => 'Référer';

  @override
  String get referralBeneficiary => 'Patiente';

  @override
  String get referralToSite => 'Site destinataire';

  @override
  String get referralReason => 'Motif (facultatif)';

  @override
  String get referralNoSites =>
      'Liste des sites indisponible. Synchronisez une première fois.';

  @override
  String get referralCreated => 'Référence enregistrée.';

  @override
  String get referralSelectBoth =>
      'Choisissez la bénéficiaire et le site destinataire.';

  @override
  String referralTo(String site) {
    return 'Vers : $site';
  }

  @override
  String get siteKindCsb => 'CSB';

  @override
  String get siteKindReference => 'Structure de référence';

  @override
  String get siteKindCommunity => 'Zone communautaire';

  @override
  String get alertsTitle => 'Alertes';

  @override
  String get noAlerts => 'Aucune alerte.';

  @override
  String get alertsReadOnly =>
      'Lecture seule. Mise à jour à chaque synchronisation.';

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
  String get demoTag => 'DÉMO';

  @override
  String get signsTitle => 'Signes de danger';

  @override
  String get signsIntro => 'Cochez les signes observés';

  @override
  String get signsBeneficiary => 'Patiente (facultatif)';

  @override
  String get noneSelected => 'Aucun';

  @override
  String get signsSend => 'Envoyer le signalement';

  @override
  String get signsSelectOne => 'Cochez au moins un signe.';

  @override
  String get signsOffline =>
      'Pas de connexion. Contactez directement le CSB selon la procédure locale.';

  @override
  String get signsError =>
      'Envoi impossible. Contactez directement le CSB selon la procédure locale.';

  @override
  String get signsResultTitle => 'Orientation';

  @override
  String get actionReferCsb => 'Orienter vers le CSB';

  @override
  String get actionReferAdvisor => 'Transmis au conseiller';

  @override
  String get signsCatalogMissing =>
      'Liste des signes non disponible. Connectez-vous au réseau et synchronisez. En cas d\'urgence, contactez directement le CSB selon la procédure locale.';

  @override
  String get actionReferCommunityAgent =>
      'Orienter vers l\'agent communautaire';

  @override
  String get actionReferFacility => 'Orienter vers la structure de référence';

  @override
  String actionOther(String code) {
    return 'Orientation : $code';
  }

  @override
  String get alertCreated =>
      'Alerte transmise. En attente d\'accusé de réception.';

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
  String get conflictExplain =>
      'La version du serveur a été gardée. Votre modification est conservée ici.';

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
  String get discardedReload =>
      'Modification abandonnée. Rechargement depuis le serveur.';

  @override
  String get discardedLocal =>
      'Modification abandonnée. Donnée supprimée du téléphone (jamais enregistrée sur le serveur).';

  @override
  String get entitySite => 'Site';

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

  @override
  String get appTagline => 'Suivi terrain';

  @override
  String get loginWelcome => 'Application de l\'agent communautaire';

  @override
  String get navHome => 'Accueil';

  @override
  String get navVisits => 'Mes visites';

  @override
  String get navAlert => 'Alerter';

  @override
  String greeting(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get greetingSub => 'Voici vos patientes et vos visites.';

  @override
  String get syncUpToDate => 'Données à jour';

  @override
  String get actionNewPatient => 'Nouvelle patiente';

  @override
  String get actionNewPatientSub => 'Consentement d\'abord';

  @override
  String get actionTodayVisit => 'Visite du jour';

  @override
  String toSeeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patientes à suivre',
      one: '1 patiente à suivre',
      zero: 'Rien d\'urgent',
    );
    return '$_temp0';
  }

  @override
  String get myPatients => 'Mes patientes';

  @override
  String get searchPatient => 'Rechercher une patiente…';

  @override
  String get noSearchResult => 'Aucune patiente trouvée.';

  @override
  String get statusUpToDate => 'À jour';

  @override
  String get statusToFollow => 'À suivre';

  @override
  String pregnancyMonths(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Grossesse · $n mois',
      one: 'Grossesse · 1 mois',
      zero: 'Grossesse · moins d\'1 mois',
    );
    return '$_temp0';
  }

  @override
  String get pregnancyNoDate => 'Grossesse en cours';

  @override
  String get noPregnancyShort => 'Pas de grossesse déclarée';

  @override
  String get reasonOpenAlert => 'Alerte en attente d\'accusé de réception';

  @override
  String reasonOverdue(int n, String date) {
    return 'CPN $n en retard ($date)';
  }

  @override
  String get reasonMissed => 'CPN manquée';

  @override
  String get whenToday => 'aujourd\'hui';

  @override
  String get whenTomorrow => 'demain';

  @override
  String whenInDays(int d) {
    String _temp0 = intl.Intl.pluralLogic(
      d,
      locale: localeName,
      other: 'dans $d jours',
      one: 'dans 1 jour',
    );
    return '$_temp0';
  }

  @override
  String whenLate(int d) {
    String _temp0 = intl.Intl.pluralLogic(
      d,
      locale: localeName,
      other: 'en retard de $d jours',
      one: 'en retard d\'1 jour',
    );
    return '$_temp0';
  }

  @override
  String nextAnc(int n, String when, String date) {
    return 'CPN $n : $when ($date)';
  }

  @override
  String get nextReminder => 'Prochain rappel';

  @override
  String get ancOverdueTitle => 'CPN en retard';

  @override
  String get visitsTitle => 'Mes visites';

  @override
  String visitsToday(String date) {
    return 'Aujourd\'hui · $date';
  }

  @override
  String get visitsPriority => 'À voir en priorité';

  @override
  String get visitsThisWeek => 'CPN dans les 7 jours';

  @override
  String get visitsOthers => 'Autres patientes';

  @override
  String get visitsNone => 'Rien d\'urgent aujourd\'hui.';

  @override
  String get startVisit => 'Commencer la visite';

  @override
  String get visitTitle => 'Visite du jour';

  @override
  String get visitStep1 => 'Enregistrement de la visite';

  @override
  String get visitConsentConfirm =>
      'J\'ai vu la patiente. Elle est d\'accord pour la visite.';

  @override
  String get visitNoConsent =>
      'Pas de consentement RENY actif. Recueillez l\'accord avant toute saisie.';

  @override
  String get visitStep2 => 'Signes de danger ?';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get visitSignsYesHint =>
      'Signalez les signes. Hors ligne : appelez le CSB.';

  @override
  String get visitSignsReported => 'Signalement envoyé.';

  @override
  String get visitStep3 => 'Conseils donnés';

  @override
  String get visitAdviceHint => 'Cochez les conseils donnés.';

  @override
  String get visitAdviceNone =>
      'Aucun conseil sur ce téléphone. Étape facultative.';

  @override
  String get visitStep4 => 'Planification du prochain RDV';

  @override
  String get visitAncDueQuestion => 'Cette CPN a-t-elle eu lieu ?';

  @override
  String get noPregnancyVisit =>
      'Pas de grossesse en cours : pas de calendrier CPN.';

  @override
  String get visitSave => 'Enregistrer la visite';

  @override
  String get visitAlertCsb => 'Alerter le CSB si nécessaire';

  @override
  String get visitIncomplete => 'Terminez les étapes 1 et 2.';

  @override
  String get visitSaved =>
      'Visite terminée. Les CPN cochées partent à la synchro.';

  @override
  String get visitLocalNote =>
      'Étapes 1 à 3 : liste locale, non envoyée au serveur.';

  @override
  String get patientTitle => 'Patiente';

  @override
  String ageYears(int n) {
    return '$n ans';
  }

  @override
  String get tabFollowUp => 'Suivi';

  @override
  String get tabAlerts => 'Alertes';

  @override
  String get tabHistory => 'Historique';

  @override
  String get alertBannerTitle => 'Alerte importante';

  @override
  String get alertBannerText => 'Signe de danger signalé.';

  @override
  String get alertAwaitingAck => 'En attente d\'accusé de réception.';

  @override
  String get viewAlert => 'Voir l\'alerte';

  @override
  String get noAlertsForPatient => 'Aucune alerte pour cette patiente.';

  @override
  String alertCreatedAt(String date) {
    return 'Signalée le $date';
  }

  @override
  String alertAckAt(String date) {
    return 'Accusé de réception le $date';
  }

  @override
  String get signsLead => 'Cochez les signes. Envoyez. Suivez l\'orientation.';

  @override
  String get signsWho => 'Pour quelle patiente ?';

  @override
  String get signsOnline => 'En ligne : envoi possible.';
}
