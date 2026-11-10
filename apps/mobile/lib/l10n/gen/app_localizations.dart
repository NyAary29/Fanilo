import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'FANILO'**
  String get appTitle;

  /// No description provided for @disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'FANILO ne remplace pas un professionnel de santé.'**
  String get disclaimer;

  /// No description provided for @demoBanner.
  ///
  /// In fr, this message translates to:
  /// **'DÉMO — liste non validée cliniquement'**
  String get demoBanner;

  /// No description provided for @demoData.
  ///
  /// In fr, this message translates to:
  /// **'Charger des données de démonstration (fictives)'**
  String get demoData;

  /// No description provided for @demoDataLoaded.
  ///
  /// In fr, this message translates to:
  /// **'Données de démonstration chargées.'**
  String get demoDataLoaded;

  /// No description provided for @errorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Une erreur est survenue.'**
  String get errorGeneric;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @next.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get next;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @loginTitle.
  ///
  /// In fr, this message translates to:
  /// **'Connexion'**
  String get loginTitle;

  /// No description provided for @loginField.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant'**
  String get loginField;

  /// No description provided for @passwordField.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe'**
  String get passwordField;

  /// No description provided for @loginButton.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get loginButton;

  /// No description provided for @loginErrorCredentials.
  ///
  /// In fr, this message translates to:
  /// **'Identifiant ou mot de passe incorrect.'**
  String get loginErrorCredentials;

  /// No description provided for @loginErrorOffline.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. La première connexion demande le réseau.'**
  String get loginErrorOffline;

  /// No description provided for @loginErrorDifferentUser.
  ///
  /// In fr, this message translates to:
  /// **'Un autre compte est ouvert sur ce téléphone. Déconnectez-le d\'abord.'**
  String get loginErrorDifferentUser;

  /// No description provided for @loginErrorGeneric.
  ///
  /// In fr, this message translates to:
  /// **'Connexion impossible. Réessayez.'**
  String get loginErrorGeneric;

  /// No description provided for @homeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get homeTitle;

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser'**
  String get syncNow;

  /// No description provided for @syncRunning.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation…'**
  String get syncRunning;

  /// No description provided for @syncLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchro : {when}'**
  String syncLast(String when);

  /// No description provided for @syncNever.
  ///
  /// In fr, this message translates to:
  /// **'Jamais synchronisé'**
  String get syncNever;

  /// No description provided for @syncPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Rien en attente} =1{1 modification en attente} other{{count} modifications en attente}}'**
  String syncPending(int count);

  /// No description provided for @syncErrorOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne. Les données restent sur le téléphone.'**
  String get syncErrorOffline;

  /// No description provided for @syncErrorSession.
  ///
  /// In fr, this message translates to:
  /// **'Reconnectez-vous pour synchroniser.'**
  String get syncErrorSession;

  /// No description provided for @syncErrorServer.
  ///
  /// In fr, this message translates to:
  /// **'Serveur indisponible. Nouvel essai plus tard.'**
  String get syncErrorServer;

  /// No description provided for @syncDone.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation terminée.'**
  String get syncDone;

  /// No description provided for @online.
  ///
  /// In fr, this message translates to:
  /// **'En ligne'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get offline;

  /// No description provided for @rejectedCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 envoi refusé, à vérifier} other{{count} envois refusés, à vérifier}}'**
  String rejectedCount(int count);

  /// No description provided for @conflictsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 conflit à revoir} other{{count} conflits à revoir}}'**
  String conflictsCount(int count);

  /// No description provided for @upcomingAnc.
  ///
  /// In fr, this message translates to:
  /// **'CPN à venir (7 jours)'**
  String get upcomingAnc;

  /// No description provided for @noUpcomingAnc.
  ///
  /// In fr, this message translates to:
  /// **'Aucune CPN prévue.'**
  String get noUpcomingAnc;

  /// No description provided for @overdue.
  ///
  /// In fr, this message translates to:
  /// **'En retard'**
  String get overdue;

  /// No description provided for @openAlerts.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune alerte ouverte} =1{1 alerte ouverte} other{{count} alertes ouvertes}}'**
  String openAlerts(int count);

  /// No description provided for @menuReferrals.
  ///
  /// In fr, this message translates to:
  /// **'Références'**
  String get menuReferrals;

  /// No description provided for @menuAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get menuAlerts;

  /// No description provided for @menuConflicts.
  ///
  /// In fr, this message translates to:
  /// **'Conflits'**
  String get menuConflicts;

  /// No description provided for @logout.
  ///
  /// In fr, this message translates to:
  /// **'Se déconnecter'**
  String get logout;

  /// No description provided for @logoutConfirmPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 modification n\'est pas encore envoyée et sera perdue.} other{{count} modifications ne sont pas encore envoyées et seront perdues.}} Se déconnecter ?'**
  String logoutConfirmPending(int count);

  /// No description provided for @logoutConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Les données de ce téléphone seront effacées. Se déconnecter ?'**
  String get logoutConfirm;

  /// No description provided for @reauthBanner.
  ///
  /// In fr, this message translates to:
  /// **'Session expirée. Reconnectez-vous pour synchroniser.'**
  String get reauthBanner;

  /// No description provided for @reauthButton.
  ///
  /// In fr, this message translates to:
  /// **'Se reconnecter'**
  String get reauthButton;

  /// No description provided for @noBeneficiaries.
  ///
  /// In fr, this message translates to:
  /// **'Aucune patiente. Touchez « Nouvelle patiente ».'**
  String get noBeneficiaries;

  /// No description provided for @codePending.
  ///
  /// In fr, this message translates to:
  /// **'Code en attente'**
  String get codePending;

  /// No description provided for @registerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle patiente'**
  String get registerTitle;

  /// No description provided for @stepConsent.
  ///
  /// In fr, this message translates to:
  /// **'Consentement'**
  String get stepConsent;

  /// No description provided for @stepIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get stepIdentity;

  /// No description provided for @consentIntro.
  ///
  /// In fr, this message translates to:
  /// **'Présentez l\'information. Recueillez l\'accord avant toute saisie.'**
  String get consentIntro;

  /// No description provided for @consentScopes.
  ///
  /// In fr, this message translates to:
  /// **'Portée du consentement'**
  String get consentScopes;

  /// No description provided for @scopeReny.
  ///
  /// In fr, this message translates to:
  /// **'Suivi de grossesse (RENY)'**
  String get scopeReny;

  /// No description provided for @scopeTanora.
  ///
  /// In fr, this message translates to:
  /// **'Jeunes (TANORA)'**
  String get scopeTanora;

  /// No description provided for @scopeReminders.
  ///
  /// In fr, this message translates to:
  /// **'Rappels'**
  String get scopeReminders;

  /// No description provided for @scopeVoice.
  ///
  /// In fr, this message translates to:
  /// **'Traitement de la voix'**
  String get scopeVoice;

  /// No description provided for @consentMethod.
  ///
  /// In fr, this message translates to:
  /// **'Méthode'**
  String get consentMethod;

  /// No description provided for @methodOral.
  ///
  /// In fr, this message translates to:
  /// **'Orale'**
  String get methodOral;

  /// No description provided for @methodWritten.
  ///
  /// In fr, this message translates to:
  /// **'Écrite'**
  String get methodWritten;

  /// No description provided for @infoVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version de l\'information présentée'**
  String get infoVersion;

  /// No description provided for @infoVersionOf.
  ///
  /// In fr, this message translates to:
  /// **'Information version {version}'**
  String infoVersionOf(String version);

  /// No description provided for @consentInfoMissing.
  ///
  /// In fr, this message translates to:
  /// **'Information de consentement non disponible. Connectez-vous au réseau et synchronisez une première fois.'**
  String get consentInfoMissing;

  /// No description provided for @consentInfoDemo.
  ///
  /// In fr, this message translates to:
  /// **'DÉMO — information de consentement non validée'**
  String get consentInfoDemo;

  /// No description provided for @consentScopeUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Information non disponible pour cette portée.'**
  String get consentScopeUnavailable;

  /// No description provided for @infoPresented.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai présenté l\'information. La personne est d\'accord.'**
  String get infoPresented;

  /// No description provided for @consentIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Consentement obligatoire avant de continuer.'**
  String get consentIncomplete;

  /// No description provided for @identityConfidential.
  ///
  /// In fr, this message translates to:
  /// **'Identité (confidentielle)'**
  String get identityConfidential;

  /// No description provided for @displayName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get displayName;

  /// No description provided for @phone.
  ///
  /// In fr, this message translates to:
  /// **'Téléphone (facultatif)'**
  String get phone;

  /// No description provided for @village.
  ///
  /// In fr, this message translates to:
  /// **'Village (facultatif)'**
  String get village;

  /// No description provided for @followUp.
  ///
  /// In fr, this message translates to:
  /// **'Suivi (sans nom)'**
  String get followUp;

  /// No description provided for @birthYear.
  ///
  /// In fr, this message translates to:
  /// **'Année de naissance (facultatif)'**
  String get birthYear;

  /// No description provided for @preferredChannel.
  ///
  /// In fr, this message translates to:
  /// **'Canal préféré'**
  String get preferredChannel;

  /// No description provided for @channelSms.
  ///
  /// In fr, this message translates to:
  /// **'SMS'**
  String get channelSms;

  /// No description provided for @channelIvr.
  ///
  /// In fr, this message translates to:
  /// **'Message vocal'**
  String get channelIvr;

  /// No description provided for @channelAcVisit.
  ///
  /// In fr, this message translates to:
  /// **'Visite de l\'AC'**
  String get channelAcVisit;

  /// No description provided for @channelNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get channelNone;

  /// No description provided for @registered.
  ///
  /// In fr, this message translates to:
  /// **'Patiente enregistrée.'**
  String get registered;

  /// No description provided for @nameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get nameRequired;

  /// No description provided for @invalidBirthYear.
  ///
  /// In fr, this message translates to:
  /// **'Année invalide.'**
  String get invalidBirthYear;

  /// No description provided for @beneficiaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get beneficiaryTitle;

  /// No description provided for @consentsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Consentements'**
  String get consentsTitle;

  /// No description provided for @consentActive.
  ///
  /// In fr, this message translates to:
  /// **'Actif'**
  String get consentActive;

  /// No description provided for @consentWithdrawn.
  ///
  /// In fr, this message translates to:
  /// **'Retiré'**
  String get consentWithdrawn;

  /// No description provided for @withdraw.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get withdraw;

  /// No description provided for @withdrawConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Retirer ce consentement ? Les rappels liés seront arrêtés.'**
  String get withdrawConfirm;

  /// No description provided for @pendingSync.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'envoi'**
  String get pendingSync;

  /// No description provided for @pregnancyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Grossesse'**
  String get pregnancyTitle;

  /// No description provided for @noPregnancy.
  ///
  /// In fr, this message translates to:
  /// **'Aucune grossesse déclarée.'**
  String get noPregnancy;

  /// No description provided for @declarePregnancy.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer une grossesse'**
  String get declarePregnancy;

  /// No description provided for @lmpDate.
  ///
  /// In fr, this message translates to:
  /// **'Date des dernières règles (facultatif)'**
  String get lmpDate;

  /// No description provided for @pickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir une date'**
  String get pickDate;

  /// No description provided for @confirmedBy.
  ///
  /// In fr, this message translates to:
  /// **'Dates confirmées par'**
  String get confirmedBy;

  /// No description provided for @confirmedAc.
  ///
  /// In fr, this message translates to:
  /// **'Déclaration (AC)'**
  String get confirmedAc;

  /// No description provided for @confirmedHealthWorker.
  ///
  /// In fr, this message translates to:
  /// **'Agent de santé'**
  String get confirmedHealthWorker;

  /// No description provided for @confirmedUltrasound.
  ///
  /// In fr, this message translates to:
  /// **'Échographie'**
  String get confirmedUltrasound;

  /// No description provided for @needRenyConsent.
  ///
  /// In fr, this message translates to:
  /// **'Consentement RENY actif requis.'**
  String get needRenyConsent;

  /// No description provided for @pregnancyActive.
  ///
  /// In fr, this message translates to:
  /// **'En cours'**
  String get pregnancyActive;

  /// No description provided for @pregnancyDelivered.
  ///
  /// In fr, this message translates to:
  /// **'Accouchement'**
  String get pregnancyDelivered;

  /// No description provided for @pregnancyEnded.
  ///
  /// In fr, this message translates to:
  /// **'Terminée'**
  String get pregnancyEnded;

  /// No description provided for @pregnancyTransferred.
  ///
  /// In fr, this message translates to:
  /// **'Transférée'**
  String get pregnancyTransferred;

  /// No description provided for @ancCalendar.
  ///
  /// In fr, this message translates to:
  /// **'Calendrier CPN'**
  String get ancCalendar;

  /// No description provided for @ancWaiting.
  ///
  /// In fr, this message translates to:
  /// **'Le calendrier arrivera après la synchronisation.'**
  String get ancWaiting;

  /// No description provided for @ancVisit.
  ///
  /// In fr, this message translates to:
  /// **'CPN {n} — {date}'**
  String ancVisit(int n, String date);

  /// No description provided for @ancNeedsLmp.
  ///
  /// In fr, this message translates to:
  /// **'Pas de calendrier CPN : le serveur le calcule à partir de la date des dernières règles (ou du terme prévu). Renseignez-la avec « Dates de la grossesse ».'**
  String get ancNeedsLmp;

  /// No description provided for @editPregnancyDates.
  ///
  /// In fr, this message translates to:
  /// **'Dates de la grossesse'**
  String get editPregnancyDates;

  /// No description provided for @dueDate.
  ///
  /// In fr, this message translates to:
  /// **'Date prévue d\'accouchement (facultatif, si connue)'**
  String get dueDate;

  /// No description provided for @clearDate.
  ///
  /// In fr, this message translates to:
  /// **'Effacer la date'**
  String get clearDate;

  /// No description provided for @datesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Dates enregistrées. Le calendrier viendra du serveur.'**
  String get datesSaved;

  /// No description provided for @datesLmpInFuture.
  ///
  /// In fr, this message translates to:
  /// **'La date des dernières règles ne peut pas être dans le futur.'**
  String get datesLmpInFuture;

  /// No description provided for @datesLmpTooOld.
  ///
  /// In fr, this message translates to:
  /// **'Date des dernières règles trop ancienne.'**
  String get datesLmpTooOld;

  /// No description provided for @datesDueBeforeLmp.
  ///
  /// In fr, this message translates to:
  /// **'La date prévue doit suivre les dernières règles.'**
  String get datesDueBeforeLmp;

  /// No description provided for @ancPlanned.
  ///
  /// In fr, this message translates to:
  /// **'Prévue'**
  String get ancPlanned;

  /// No description provided for @ancDone.
  ///
  /// In fr, this message translates to:
  /// **'Réalisée'**
  String get ancDone;

  /// No description provided for @ancMissed.
  ///
  /// In fr, this message translates to:
  /// **'Manquée'**
  String get ancMissed;

  /// No description provided for @ancCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get ancCancelled;

  /// No description provided for @markDone.
  ///
  /// In fr, this message translates to:
  /// **'Réalisée'**
  String get markDone;

  /// No description provided for @markMissed.
  ///
  /// In fr, this message translates to:
  /// **'Manquée'**
  String get markMissed;

  /// No description provided for @referralsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Références'**
  String get referralsTitle;

  /// No description provided for @noReferrals.
  ///
  /// In fr, this message translates to:
  /// **'Aucune référence.'**
  String get noReferrals;

  /// No description provided for @referralProposed.
  ///
  /// In fr, this message translates to:
  /// **'Proposée'**
  String get referralProposed;

  /// No description provided for @referralAccepted.
  ///
  /// In fr, this message translates to:
  /// **'Acceptée'**
  String get referralAccepted;

  /// No description provided for @referralArrived.
  ///
  /// In fr, this message translates to:
  /// **'Arrivée'**
  String get referralArrived;

  /// No description provided for @referralTransferred.
  ///
  /// In fr, this message translates to:
  /// **'Transférée'**
  String get referralTransferred;

  /// No description provided for @referralNotCompleted.
  ///
  /// In fr, this message translates to:
  /// **'Non aboutie'**
  String get referralNotCompleted;

  /// No description provided for @changeStatus.
  ///
  /// In fr, this message translates to:
  /// **'Changer le statut'**
  String get changeStatus;

  /// No description provided for @reasonRequired.
  ///
  /// In fr, this message translates to:
  /// **'Motif (obligatoire)'**
  String get reasonRequired;

  /// No description provided for @outcomeNote.
  ///
  /// In fr, this message translates to:
  /// **'Note (facultatif)'**
  String get outcomeNote;

  /// No description provided for @noTransition.
  ///
  /// In fr, this message translates to:
  /// **'Aucune action possible.'**
  String get noTransition;

  /// No description provided for @referralNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle référence'**
  String get referralNew;

  /// No description provided for @referralRefer.
  ///
  /// In fr, this message translates to:
  /// **'Référer'**
  String get referralRefer;

  /// No description provided for @referralBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Patiente'**
  String get referralBeneficiary;

  /// No description provided for @referralToSite.
  ///
  /// In fr, this message translates to:
  /// **'Site destinataire'**
  String get referralToSite;

  /// No description provided for @referralReason.
  ///
  /// In fr, this message translates to:
  /// **'Motif (facultatif)'**
  String get referralReason;

  /// No description provided for @referralNoSites.
  ///
  /// In fr, this message translates to:
  /// **'Liste des sites indisponible. Synchronisez une première fois.'**
  String get referralNoSites;

  /// No description provided for @referralCreated.
  ///
  /// In fr, this message translates to:
  /// **'Référence enregistrée.'**
  String get referralCreated;

  /// No description provided for @referralSelectBoth.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la bénéficiaire et le site destinataire.'**
  String get referralSelectBoth;

  /// No description provided for @referralTo.
  ///
  /// In fr, this message translates to:
  /// **'Vers : {site}'**
  String referralTo(String site);

  /// No description provided for @siteKindCsb.
  ///
  /// In fr, this message translates to:
  /// **'CSB'**
  String get siteKindCsb;

  /// No description provided for @siteKindReference.
  ///
  /// In fr, this message translates to:
  /// **'Structure de référence'**
  String get siteKindReference;

  /// No description provided for @siteKindCommunity.
  ///
  /// In fr, this message translates to:
  /// **'Zone communautaire'**
  String get siteKindCommunity;

  /// No description provided for @alertsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get alertsTitle;

  /// No description provided for @noAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte.'**
  String get noAlerts;

  /// No description provided for @alertsReadOnly.
  ///
  /// In fr, this message translates to:
  /// **'Lecture seule. Mise à jour à chaque synchronisation.'**
  String get alertsReadOnly;

  /// No description provided for @alertOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouverte'**
  String get alertOpen;

  /// No description provided for @alertAcknowledged.
  ///
  /// In fr, this message translates to:
  /// **'Accusé de réception'**
  String get alertAcknowledged;

  /// No description provided for @alertResolved.
  ///
  /// In fr, this message translates to:
  /// **'Résolue'**
  String get alertResolved;

  /// No description provided for @alertEscalated.
  ///
  /// In fr, this message translates to:
  /// **'Escaladée'**
  String get alertEscalated;

  /// No description provided for @alertCancelled.
  ///
  /// In fr, this message translates to:
  /// **'Annulée'**
  String get alertCancelled;

  /// No description provided for @demoTag.
  ///
  /// In fr, this message translates to:
  /// **'DÉMO'**
  String get demoTag;

  /// No description provided for @signsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Signes de danger'**
  String get signsTitle;

  /// No description provided for @signsIntro.
  ///
  /// In fr, this message translates to:
  /// **'Cochez les signes observés'**
  String get signsIntro;

  /// No description provided for @signsBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Patiente (facultatif)'**
  String get signsBeneficiary;

  /// No description provided for @noneSelected.
  ///
  /// In fr, this message translates to:
  /// **'Aucun'**
  String get noneSelected;

  /// No description provided for @signsSend.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer le signalement'**
  String get signsSend;

  /// No description provided for @signsSelectOne.
  ///
  /// In fr, this message translates to:
  /// **'Cochez au moins un signe.'**
  String get signsSelectOne;

  /// No description provided for @signsOffline.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Contactez directement le CSB selon la procédure locale.'**
  String get signsOffline;

  /// No description provided for @signsError.
  ///
  /// In fr, this message translates to:
  /// **'Envoi impossible. Contactez directement le CSB selon la procédure locale.'**
  String get signsError;

  /// No description provided for @signsResultTitle.
  ///
  /// In fr, this message translates to:
  /// **'Orientation'**
  String get signsResultTitle;

  /// No description provided for @actionReferCsb.
  ///
  /// In fr, this message translates to:
  /// **'Orienter vers le CSB'**
  String get actionReferCsb;

  /// No description provided for @actionReferAdvisor.
  ///
  /// In fr, this message translates to:
  /// **'Transmis au conseiller'**
  String get actionReferAdvisor;

  /// No description provided for @signsCatalogMissing.
  ///
  /// In fr, this message translates to:
  /// **'Liste des signes non disponible. Connectez-vous au réseau et synchronisez. En cas d\'urgence, contactez directement le CSB selon la procédure locale.'**
  String get signsCatalogMissing;

  /// No description provided for @actionReferCommunityAgent.
  ///
  /// In fr, this message translates to:
  /// **'Orienter vers l\'agent communautaire'**
  String get actionReferCommunityAgent;

  /// No description provided for @actionReferFacility.
  ///
  /// In fr, this message translates to:
  /// **'Orienter vers la structure de référence'**
  String get actionReferFacility;

  /// No description provided for @actionOther.
  ///
  /// In fr, this message translates to:
  /// **'Orientation : {code}'**
  String actionOther(String code);

  /// No description provided for @alertCreated.
  ///
  /// In fr, this message translates to:
  /// **'Alerte transmise. En attente d\'accusé de réception.'**
  String get alertCreated;

  /// No description provided for @fallbackOutcome.
  ///
  /// In fr, this message translates to:
  /// **'Transmis au conseiller pour avis.'**
  String get fallbackOutcome;

  /// No description provided for @demoContent.
  ///
  /// In fr, this message translates to:
  /// **'Contenu de démonstration'**
  String get demoContent;

  /// No description provided for @newReport.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau signalement'**
  String get newReport;

  /// No description provided for @conflictsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Conflits de synchronisation'**
  String get conflictsTitle;

  /// No description provided for @noConflicts.
  ///
  /// In fr, this message translates to:
  /// **'Aucun conflit.'**
  String get noConflicts;

  /// No description provided for @conflictExplain.
  ///
  /// In fr, this message translates to:
  /// **'La version du serveur a été gardée. Votre modification est conservée ici.'**
  String get conflictExplain;

  /// No description provided for @conflictLocal.
  ///
  /// In fr, this message translates to:
  /// **'Votre version'**
  String get conflictLocal;

  /// No description provided for @conflictServer.
  ///
  /// In fr, this message translates to:
  /// **'Version du serveur'**
  String get conflictServer;

  /// No description provided for @keepServer.
  ///
  /// In fr, this message translates to:
  /// **'Garder le serveur'**
  String get keepServer;

  /// No description provided for @reapplyLocal.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer ma version'**
  String get reapplyLocal;

  /// No description provided for @rejectedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Envois refusés'**
  String get rejectedTitle;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @discard.
  ///
  /// In fr, this message translates to:
  /// **'Abandonner'**
  String get discard;

  /// No description provided for @discardedReload.
  ///
  /// In fr, this message translates to:
  /// **'Modification abandonnée. Rechargement depuis le serveur.'**
  String get discardedReload;

  /// No description provided for @discardedLocal.
  ///
  /// In fr, this message translates to:
  /// **'Modification abandonnée. Donnée supprimée du téléphone (jamais enregistrée sur le serveur).'**
  String get discardedLocal;

  /// No description provided for @entitySite.
  ///
  /// In fr, this message translates to:
  /// **'Site'**
  String get entitySite;

  /// No description provided for @entityBeneficiary.
  ///
  /// In fr, this message translates to:
  /// **'Bénéficiaire'**
  String get entityBeneficiary;

  /// No description provided for @entityIdentity.
  ///
  /// In fr, this message translates to:
  /// **'Identité'**
  String get entityIdentity;

  /// No description provided for @entityConsent.
  ///
  /// In fr, this message translates to:
  /// **'Consentement'**
  String get entityConsent;

  /// No description provided for @entityPregnancy.
  ///
  /// In fr, this message translates to:
  /// **'Grossesse'**
  String get entityPregnancy;

  /// No description provided for @entityAncVisit.
  ///
  /// In fr, this message translates to:
  /// **'CPN'**
  String get entityAncVisit;

  /// No description provided for @entityReferral.
  ///
  /// In fr, this message translates to:
  /// **'Référence'**
  String get entityReferral;

  /// No description provided for @entityAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte'**
  String get entityAlert;

  /// No description provided for @appTagline.
  ///
  /// In fr, this message translates to:
  /// **'Suivi terrain'**
  String get appTagline;

  /// No description provided for @loginWelcome.
  ///
  /// In fr, this message translates to:
  /// **'Application de l\'agent communautaire'**
  String get loginWelcome;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navVisits.
  ///
  /// In fr, this message translates to:
  /// **'Mes visites'**
  String get navVisits;

  /// No description provided for @navAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerter'**
  String get navAlert;

  /// No description provided for @greeting.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour, {name}'**
  String greeting(String name);

  /// No description provided for @greetingSub.
  ///
  /// In fr, this message translates to:
  /// **'Voici vos patientes et vos visites.'**
  String get greetingSub;

  /// No description provided for @syncUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'Données à jour'**
  String get syncUpToDate;

  /// No description provided for @actionNewPatient.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle patiente'**
  String get actionNewPatient;

  /// No description provided for @actionNewPatientSub.
  ///
  /// In fr, this message translates to:
  /// **'Consentement d\'abord'**
  String get actionNewPatientSub;

  /// No description provided for @actionTodayVisit.
  ///
  /// In fr, this message translates to:
  /// **'Visite du jour'**
  String get actionTodayVisit;

  /// No description provided for @toSeeCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Rien d\'urgent} =1{1 patiente à suivre} other{{count} patientes à suivre}}'**
  String toSeeCount(int count);

  /// No description provided for @myPatients.
  ///
  /// In fr, this message translates to:
  /// **'Mes patientes'**
  String get myPatients;

  /// No description provided for @searchPatient.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher une patiente…'**
  String get searchPatient;

  /// No description provided for @noSearchResult.
  ///
  /// In fr, this message translates to:
  /// **'Aucune patiente trouvée.'**
  String get noSearchResult;

  /// No description provided for @statusUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get statusUpToDate;

  /// No description provided for @statusToFollow.
  ///
  /// In fr, this message translates to:
  /// **'À suivre'**
  String get statusToFollow;

  /// No description provided for @pregnancyMonths.
  ///
  /// In fr, this message translates to:
  /// **'{n, plural, =0{Grossesse · moins d\'1 mois} =1{Grossesse · 1 mois} other{Grossesse · {n} mois}}'**
  String pregnancyMonths(int n);

  /// No description provided for @pregnancyNoDate.
  ///
  /// In fr, this message translates to:
  /// **'Grossesse en cours'**
  String get pregnancyNoDate;

  /// No description provided for @noPregnancyShort.
  ///
  /// In fr, this message translates to:
  /// **'Pas de grossesse déclarée'**
  String get noPregnancyShort;

  /// No description provided for @reasonOpenAlert.
  ///
  /// In fr, this message translates to:
  /// **'Alerte en attente d\'accusé de réception'**
  String get reasonOpenAlert;

  /// No description provided for @reasonOverdue.
  ///
  /// In fr, this message translates to:
  /// **'CPN {n} en retard ({date})'**
  String reasonOverdue(int n, String date);

  /// No description provided for @reasonMissed.
  ///
  /// In fr, this message translates to:
  /// **'CPN manquée'**
  String get reasonMissed;

  /// No description provided for @whenToday.
  ///
  /// In fr, this message translates to:
  /// **'aujourd\'hui'**
  String get whenToday;

  /// No description provided for @whenTomorrow.
  ///
  /// In fr, this message translates to:
  /// **'demain'**
  String get whenTomorrow;

  /// No description provided for @whenInDays.
  ///
  /// In fr, this message translates to:
  /// **'{d, plural, =1{dans 1 jour} other{dans {d} jours}}'**
  String whenInDays(int d);

  /// No description provided for @whenLate.
  ///
  /// In fr, this message translates to:
  /// **'{d, plural, =1{en retard d\'1 jour} other{en retard de {d} jours}}'**
  String whenLate(int d);

  /// No description provided for @nextAnc.
  ///
  /// In fr, this message translates to:
  /// **'CPN {n} : {when} ({date})'**
  String nextAnc(int n, String when, String date);

  /// No description provided for @nextReminder.
  ///
  /// In fr, this message translates to:
  /// **'Prochain rappel'**
  String get nextReminder;

  /// No description provided for @ancOverdueTitle.
  ///
  /// In fr, this message translates to:
  /// **'CPN en retard'**
  String get ancOverdueTitle;

  /// No description provided for @visitsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Mes visites'**
  String get visitsTitle;

  /// No description provided for @visitsToday.
  ///
  /// In fr, this message translates to:
  /// **'Aujourd\'hui · {date}'**
  String visitsToday(String date);

  /// No description provided for @visitsPriority.
  ///
  /// In fr, this message translates to:
  /// **'À voir en priorité'**
  String get visitsPriority;

  /// No description provided for @visitsThisWeek.
  ///
  /// In fr, this message translates to:
  /// **'CPN dans les 7 jours'**
  String get visitsThisWeek;

  /// No description provided for @visitsOthers.
  ///
  /// In fr, this message translates to:
  /// **'Autres patientes'**
  String get visitsOthers;

  /// No description provided for @visitsNone.
  ///
  /// In fr, this message translates to:
  /// **'Rien d\'urgent aujourd\'hui.'**
  String get visitsNone;

  /// No description provided for @startVisit.
  ///
  /// In fr, this message translates to:
  /// **'Commencer la visite'**
  String get startVisit;

  /// No description provided for @visitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Visite du jour'**
  String get visitTitle;

  /// No description provided for @visitStep1.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrement de la visite'**
  String get visitStep1;

  /// No description provided for @visitConsentConfirm.
  ///
  /// In fr, this message translates to:
  /// **'J\'ai vu la patiente. Elle est d\'accord pour la visite.'**
  String get visitConsentConfirm;

  /// No description provided for @visitNoConsent.
  ///
  /// In fr, this message translates to:
  /// **'Pas de consentement RENY actif. Recueillez l\'accord avant toute saisie.'**
  String get visitNoConsent;

  /// No description provided for @visitStep2.
  ///
  /// In fr, this message translates to:
  /// **'Signes de danger ?'**
  String get visitStep2;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In fr, this message translates to:
  /// **'Non'**
  String get no;

  /// No description provided for @visitSignsYesHint.
  ///
  /// In fr, this message translates to:
  /// **'Signalez les signes. Hors ligne : appelez le CSB.'**
  String get visitSignsYesHint;

  /// No description provided for @visitSignsReported.
  ///
  /// In fr, this message translates to:
  /// **'Signalement envoyé.'**
  String get visitSignsReported;

  /// No description provided for @visitStep3.
  ///
  /// In fr, this message translates to:
  /// **'Conseils donnés'**
  String get visitStep3;

  /// No description provided for @visitAdviceHint.
  ///
  /// In fr, this message translates to:
  /// **'Cochez les conseils donnés.'**
  String get visitAdviceHint;

  /// No description provided for @visitAdviceNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun conseil sur ce téléphone. Étape facultative.'**
  String get visitAdviceNone;

  /// No description provided for @visitStep4.
  ///
  /// In fr, this message translates to:
  /// **'Planification du prochain RDV'**
  String get visitStep4;

  /// No description provided for @visitAncDueQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Cette CPN a-t-elle eu lieu ?'**
  String get visitAncDueQuestion;

  /// No description provided for @noPregnancyVisit.
  ///
  /// In fr, this message translates to:
  /// **'Pas de grossesse en cours : pas de calendrier CPN.'**
  String get noPregnancyVisit;

  /// No description provided for @visitSave.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la visite'**
  String get visitSave;

  /// No description provided for @visitAlertCsb.
  ///
  /// In fr, this message translates to:
  /// **'Alerter le CSB si nécessaire'**
  String get visitAlertCsb;

  /// No description provided for @visitIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Terminez les étapes 1 et 2.'**
  String get visitIncomplete;

  /// No description provided for @visitSaved.
  ///
  /// In fr, this message translates to:
  /// **'Visite terminée. Les CPN cochées partent à la synchro.'**
  String get visitSaved;

  /// No description provided for @visitLocalNote.
  ///
  /// In fr, this message translates to:
  /// **'Étapes 1 à 3 : liste locale, non envoyée au serveur.'**
  String get visitLocalNote;

  /// No description provided for @patientTitle.
  ///
  /// In fr, this message translates to:
  /// **'Patiente'**
  String get patientTitle;

  /// No description provided for @ageYears.
  ///
  /// In fr, this message translates to:
  /// **'{n} ans'**
  String ageYears(int n);

  /// No description provided for @tabFollowUp.
  ///
  /// In fr, this message translates to:
  /// **'Suivi'**
  String get tabFollowUp;

  /// No description provided for @tabAlerts.
  ///
  /// In fr, this message translates to:
  /// **'Alertes'**
  String get tabAlerts;

  /// No description provided for @tabHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique'**
  String get tabHistory;

  /// No description provided for @alertBannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Alerte importante'**
  String get alertBannerTitle;

  /// No description provided for @alertBannerText.
  ///
  /// In fr, this message translates to:
  /// **'Signe de danger signalé.'**
  String get alertBannerText;

  /// No description provided for @alertAwaitingAck.
  ///
  /// In fr, this message translates to:
  /// **'En attente d\'accusé de réception.'**
  String get alertAwaitingAck;

  /// No description provided for @viewAlert.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'alerte'**
  String get viewAlert;

  /// No description provided for @noAlertsForPatient.
  ///
  /// In fr, this message translates to:
  /// **'Aucune alerte pour cette patiente.'**
  String get noAlertsForPatient;

  /// No description provided for @alertCreatedAt.
  ///
  /// In fr, this message translates to:
  /// **'Signalée le {date}'**
  String alertCreatedAt(String date);

  /// No description provided for @alertAckAt.
  ///
  /// In fr, this message translates to:
  /// **'Accusé de réception le {date}'**
  String alertAckAt(String date);

  /// No description provided for @signsLead.
  ///
  /// In fr, this message translates to:
  /// **'Cochez les signes. Envoyez. Suivez l\'orientation.'**
  String get signsLead;

  /// No description provided for @signsWho.
  ///
  /// In fr, this message translates to:
  /// **'Pour quelle patiente ?'**
  String get signsWho;

  /// No description provided for @signsOnline.
  ///
  /// In fr, this message translates to:
  /// **'En ligne : envoi possible.'**
  String get signsOnline;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
