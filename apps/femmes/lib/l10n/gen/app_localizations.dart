import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';
import 'app_localizations_mg.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('fr'),
    Locale('mg'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'FANILO'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In fr, this message translates to:
  /// **'La santé pour toutes'**
  String get tagline;

  /// No description provided for @hello.
  ///
  /// In fr, this message translates to:
  /// **'Bonjour !'**
  String get hello;

  /// No description provided for @homeSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Posez la question qui vous préoccupe.'**
  String get homeSubtitle;

  /// No description provided for @micHint.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez et parlez'**
  String get micHint;

  /// No description provided for @micStop.
  ///
  /// In fr, this message translates to:
  /// **'Appuyez encore pour envoyer'**
  String get micStop;

  /// No description provided for @micListening.
  ///
  /// In fr, this message translates to:
  /// **'J\'écoute…'**
  String get micListening;

  /// No description provided for @sending.
  ///
  /// In fr, this message translates to:
  /// **'Envoi…'**
  String get sending;

  /// No description provided for @renySubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Santé pendant la grossesse'**
  String get renySubtitle;

  /// No description provided for @tanoraSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Santé des adolescentes'**
  String get tanoraSubtitle;

  /// No description provided for @writeHint.
  ///
  /// In fr, this message translates to:
  /// **'Écrivez votre question'**
  String get writeHint;

  /// No description provided for @send.
  ///
  /// In fr, this message translates to:
  /// **'Envoyer'**
  String get send;

  /// No description provided for @chooseModule.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez d\'abord : RENY ou TANORA'**
  String get chooseModule;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navInfo.
  ///
  /// In fr, this message translates to:
  /// **'Informations'**
  String get navInfo;

  /// No description provided for @navMine.
  ///
  /// In fr, this message translates to:
  /// **'Mes questions'**
  String get navMine;

  /// No description provided for @emergency.
  ///
  /// In fr, this message translates to:
  /// **'Urgence'**
  String get emergency;

  /// No description provided for @goNow.
  ///
  /// In fr, this message translates to:
  /// **'Allez au centre de santé le plus proche, sans attendre.'**
  String get goNow;

  /// No description provided for @emergencyCompanion.
  ///
  /// In fr, this message translates to:
  /// **'Demandez à quelqu\'un de vous accompagner.'**
  String get emergencyCompanion;

  /// No description provided for @emergencyNoCall.
  ///
  /// In fr, this message translates to:
  /// **'FANILO ne peut appeler personne. Personne n\'est prévenu.'**
  String get emergencyNoCall;

  /// No description provided for @emergencyYourCsb.
  ///
  /// In fr, this message translates to:
  /// **'Votre CSB : {name}'**
  String emergencyYourCsb(String name);

  /// No description provided for @localProcedure.
  ///
  /// In fr, this message translates to:
  /// **'Procédure locale'**
  String get localProcedure;

  /// No description provided for @disclaimer.
  ///
  /// In fr, this message translates to:
  /// **'FANILO ne remplace pas un professionnel de santé.'**
  String get disclaimer;

  /// No description provided for @demoBanner.
  ///
  /// In fr, this message translates to:
  /// **'DÉMO — contenu non validé cliniquement'**
  String get demoBanner;

  /// No description provided for @answerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réponse'**
  String get answerTitle;

  /// No description provided for @yourQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Votre question'**
  String get yourQuestion;

  /// No description provided for @transcriptReview.
  ///
  /// In fr, this message translates to:
  /// **'Le texte entendu peut contenir des erreurs.'**
  String get transcriptReview;

  /// No description provided for @sentToCounselor.
  ///
  /// In fr, this message translates to:
  /// **'Votre question a été envoyée à un conseiller.'**
  String get sentToCounselor;

  /// No description provided for @findReplyIn.
  ///
  /// In fr, this message translates to:
  /// **'Vous trouverez la réponse dans « Mes questions ».'**
  String get findReplyIn;

  /// No description provided for @noDelay.
  ///
  /// In fr, this message translates to:
  /// **'Aucun délai de réponse n\'est garanti.'**
  String get noDelay;

  /// No description provided for @seeMyQuestions.
  ///
  /// In fr, this message translates to:
  /// **'Voir mes questions'**
  String get seeMyQuestions;

  /// No description provided for @noContent.
  ///
  /// In fr, this message translates to:
  /// **'Pas de réponse ici pour l\'instant.'**
  String get noContent;

  /// No description provided for @listen.
  ///
  /// In fr, this message translates to:
  /// **'Écouter'**
  String get listen;

  /// No description provided for @stopAudio.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get stopAudio;

  /// No description provided for @askAnother.
  ///
  /// In fr, this message translates to:
  /// **'Autre question'**
  String get askAnother;

  /// No description provided for @welcomeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Bienvenue !'**
  String get welcomeTitle;

  /// No description provided for @welcomeNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Pas de compte. Ni nom, ni numéro de téléphone.'**
  String get welcomeNoAccount;

  /// No description provided for @welcomeNothingKept.
  ///
  /// In fr, this message translates to:
  /// **'Rien qui permette de vous reconnaître n\'est gardé ici.'**
  String get welcomeNothingKept;

  /// No description provided for @welcomeAudio.
  ///
  /// In fr, this message translates to:
  /// **'Votre voix n\'est jamais conservée.'**
  String get welcomeAudio;

  /// No description provided for @welcomeEmergency.
  ///
  /// In fr, this message translates to:
  /// **'Urgence : allez au centre de santé le plus proche.'**
  String get welcomeEmergency;

  /// No description provided for @voiceConsentTitle.
  ///
  /// In fr, this message translates to:
  /// **'Utiliser la voix ?'**
  String get voiceConsentTitle;

  /// No description provided for @voiceConsentBody.
  ///
  /// In fr, this message translates to:
  /// **'Votre voix est transformée en texte pour vous répondre. L\'audio n\'est pas gardé.'**
  String get voiceConsentBody;

  /// No description provided for @accept.
  ///
  /// In fr, this message translates to:
  /// **'J\'accepte'**
  String get accept;

  /// No description provided for @notNow.
  ///
  /// In fr, this message translates to:
  /// **'Pas maintenant'**
  String get notNow;

  /// No description provided for @voiceLater.
  ///
  /// In fr, this message translates to:
  /// **'Vous pouvez toujours écrire, sans la voix.'**
  String get voiceLater;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @serverInfo.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get serverInfo;

  /// No description provided for @infoUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Information indisponible (pas de réseau).'**
  String get infoUnavailable;

  /// No description provided for @whereLive.
  ///
  /// In fr, this message translates to:
  /// **'Où habitez-vous ?'**
  String get whereLive;

  /// No description provided for @whereLiveHelp.
  ///
  /// In fr, this message translates to:
  /// **'Facultatif. Gardé seulement sur ce téléphone. Sert à orienter votre question vers les conseillers de votre zone.'**
  String get whereLiveHelp;

  /// No description provided for @skip.
  ///
  /// In fr, this message translates to:
  /// **'Passer'**
  String get skip;

  /// No description provided for @searchHint.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher…'**
  String get searchHint;

  /// No description provided for @noSite.
  ///
  /// In fr, this message translates to:
  /// **'Non choisi'**
  String get noSite;

  /// No description provided for @mineEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune question envoyée à un conseiller.'**
  String get mineEmpty;

  /// No description provided for @mineNote.
  ///
  /// In fr, this message translates to:
  /// **'Seul un numéro est gardé ici, jamais le texte de vos questions.'**
  String get mineNote;

  /// No description provided for @statusPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get statusPending;

  /// No description provided for @statusAnswered.
  ///
  /// In fr, this message translates to:
  /// **'Répondu'**
  String get statusAnswered;

  /// No description provided for @statusUnknown.
  ///
  /// In fr, this message translates to:
  /// **'Introuvable'**
  String get statusUnknown;

  /// No description provided for @counselorAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Réponse du conseiller'**
  String get counselorAnswer;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get delete;

  /// No description provided for @deleteAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout effacer'**
  String get deleteAll;

  /// No description provided for @deleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Effacer cette question ?'**
  String get deleteConfirm;

  /// No description provided for @deleteAllConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Effacer toutes vos questions ?'**
  String get deleteAllConfirm;

  /// No description provided for @deleted.
  ///
  /// In fr, this message translates to:
  /// **'Effacé'**
  String get deleted;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @askedOn.
  ///
  /// In fr, this message translates to:
  /// **'Envoyée le {date}'**
  String askedOn(String date);

  /// No description provided for @menuUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'information pour le moment.'**
  String get menuUnavailable;

  /// No description provided for @errorNetwork.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion. Réessayez.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In fr, this message translates to:
  /// **'Trop de questions. Réessayez plus tard.'**
  String get errorRateLimited;

  /// No description provided for @errorConsent.
  ///
  /// In fr, this message translates to:
  /// **'Acceptez d\'abord l\'usage de la voix.'**
  String get errorConsent;

  /// No description provided for @errorOther.
  ///
  /// In fr, this message translates to:
  /// **'Un problème est survenu. Réessayez.'**
  String get errorOther;

  /// No description provided for @retry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retry;

  /// No description provided for @micPermission.
  ///
  /// In fr, this message translates to:
  /// **'FANILO a besoin du micro pour entendre votre question.'**
  String get micPermission;

  /// No description provided for @micDenied.
  ///
  /// In fr, this message translates to:
  /// **'Micro refusé. Vous pouvez écrire votre question.'**
  String get micDenied;

  /// No description provided for @settings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @voiceOn.
  ///
  /// In fr, this message translates to:
  /// **'Voix : acceptée'**
  String get voiceOn;

  /// No description provided for @voiceOff.
  ///
  /// In fr, this message translates to:
  /// **'Voix : non acceptée'**
  String get voiceOff;

  /// No description provided for @withdrawConsent.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'accord'**
  String get withdrawConsent;

  /// No description provided for @place.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get place;

  /// No description provided for @unreviewedMg.
  ///
  /// In fr, this message translates to:
  /// **'Textes malgaches à relire par des locuteurs natifs.'**
  String get unreviewedMg;

  /// No description provided for @close.
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get close;

  /// No description provided for @aboutAnonymous.
  ///
  /// In fr, this message translates to:
  /// **'Sans compte'**
  String get aboutAnonymous;

  /// No description provided for @newAnswer.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez une réponse'**
  String get newAnswer;

  /// No description provided for @see.
  ///
  /// In fr, this message translates to:
  /// **'Voir'**
  String get see;

  /// No description provided for @newLabel.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau'**
  String get newLabel;

  /// No description provided for @serverUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur'**
  String get serverUnreachable;

  /// No description provided for @checkedAt.
  ///
  /// In fr, this message translates to:
  /// **'Vérifié à {time}'**
  String checkedAt(String time);

  /// No description provided for @weUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Nous avons compris :'**
  String get weUnderstood;

  /// No description provided for @voiceNotTranscribed.
  ///
  /// In fr, this message translates to:
  /// **'Votre voix n\'a pas pu être transcrite.'**
  String get voiceNotTranscribed;

  /// No description provided for @voiceNotTranscribedFollow.
  ///
  /// In fr, this message translates to:
  /// **'Votre question est quand même transmise à un conseiller. La réponse sera dans « Mes questions ».'**
  String get voiceNotTranscribedFollow;

  /// No description provided for @voiceNotTranscribedRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayez, ou écrivez votre question.'**
  String get voiceNotTranscribedRetry;

  /// No description provided for @isThisWhatYouSaid.
  ///
  /// In fr, this message translates to:
  /// **'Est-ce bien ce que vous avez dit ?'**
  String get isThisWhatYouSaid;

  /// No description provided for @yes.
  ///
  /// In fr, this message translates to:
  /// **'Oui'**
  String get yes;

  /// No description provided for @noWrite.
  ///
  /// In fr, this message translates to:
  /// **'Non, je l\'écris'**
  String get noWrite;

  /// No description provided for @voiceNotUnderstood.
  ///
  /// In fr, this message translates to:
  /// **'Votre voix n\'a pas été bien comprise.'**
  String get voiceNotUnderstood;

  /// No description provided for @retryVoice.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get retryVoice;

  /// No description provided for @writeQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Écrire la question'**
  String get writeQuestion;

  /// No description provided for @voiceWait.
  ///
  /// In fr, this message translates to:
  /// **'Nous écoutons votre question…'**
  String get voiceWait;

  /// No description provided for @goTo.
  ///
  /// In fr, this message translates to:
  /// **'Allez à :'**
  String get goTo;

  /// No description provided for @kindHospital.
  ///
  /// In fr, this message translates to:
  /// **'Hôpital de référence'**
  String get kindHospital;

  /// No description provided for @kindCsb.
  ///
  /// In fr, this message translates to:
  /// **'Centre de santé'**
  String get kindCsb;

  /// No description provided for @triageUrgent.
  ///
  /// In fr, this message translates to:
  /// **'Urgent'**
  String get triageUrgent;

  /// No description provided for @triageFollowUp.
  ///
  /// In fr, this message translates to:
  /// **'À suivre'**
  String get triageFollowUp;

  /// No description provided for @triageInfo.
  ///
  /// In fr, this message translates to:
  /// **'Information'**
  String get triageInfo;

  /// No description provided for @showCode.
  ///
  /// In fr, this message translates to:
  /// **'Montrez ce code au centre de santé'**
  String get showCode;

  /// No description provided for @visitExpected.
  ///
  /// In fr, this message translates to:
  /// **'Le centre vous attend'**
  String get visitExpected;

  /// No description provided for @visitCame.
  ///
  /// In fr, this message translates to:
  /// **'Votre venue est enregistrée'**
  String get visitCame;

  /// No description provided for @visitNoShow.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'êtes pas encore venue : allez-y si besoin'**
  String get visitNoShow;
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
      <String>['fr', 'mg'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
    case 'mg':
      return AppLocalizationsMg();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
