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
  String get tagline => 'La santé pour toutes';

  @override
  String get hello => 'Bonjour !';

  @override
  String get homeSubtitle => 'Posez la question qui vous préoccupe.';

  @override
  String get micHint => 'Appuyez et parlez';

  @override
  String get micStop => 'Appuyez encore pour envoyer';

  @override
  String get micListening => 'J\'écoute…';

  @override
  String get sending => 'Envoi…';

  @override
  String get renySubtitle => 'Santé pendant la grossesse';

  @override
  String get tanoraSubtitle => 'Santé des adolescentes';

  @override
  String get writeHint => 'Écrivez votre question';

  @override
  String get send => 'Envoyer';

  @override
  String get chooseModule => 'Choisissez d\'abord : RENY ou TANORA';

  @override
  String get navHome => 'Accueil';

  @override
  String get navInfo => 'Informations';

  @override
  String get navMine => 'Mes questions';

  @override
  String get emergency => 'Urgence';

  @override
  String get goNow => 'Allez au centre de santé le plus proche, sans attendre.';

  @override
  String get emergencyCompanion => 'Demandez à quelqu\'un de vous accompagner.';

  @override
  String get emergencyNoCall =>
      'FANILO ne peut appeler personne. Personne n\'est prévenu.';

  @override
  String emergencyYourCsb(String name) {
    return 'Votre CSB : $name';
  }

  @override
  String get localProcedure => 'Procédure locale';

  @override
  String get disclaimer => 'FANILO ne remplace pas un professionnel de santé.';

  @override
  String get demoBanner => 'DÉMO — contenu non validé cliniquement';

  @override
  String get answerTitle => 'Réponse';

  @override
  String get yourQuestion => 'Votre question';

  @override
  String get transcriptReview => 'Le texte entendu peut contenir des erreurs.';

  @override
  String get sentToCounselor => 'Votre question a été envoyée à un conseiller.';

  @override
  String get findReplyIn => 'Vous trouverez la réponse dans « Mes questions ».';

  @override
  String get noDelay => 'Aucun délai de réponse n\'est garanti.';

  @override
  String get seeMyQuestions => 'Voir mes questions';

  @override
  String get noContent => 'Pas de réponse ici pour l\'instant.';

  @override
  String get listen => 'Écouter';

  @override
  String get stopAudio => 'Arrêter';

  @override
  String get askAnother => 'Autre question';

  @override
  String get welcomeTitle => 'Bienvenue !';

  @override
  String get welcomeNoAccount =>
      'Pas de compte. Ni nom, ni numéro de téléphone.';

  @override
  String get welcomeNothingKept =>
      'Rien qui permette de vous reconnaître n\'est gardé ici.';

  @override
  String get welcomeAudio => 'Votre voix n\'est jamais conservée.';

  @override
  String get welcomeEmergency =>
      'Urgence : allez au centre de santé le plus proche.';

  @override
  String get voiceConsentTitle => 'Utiliser la voix ?';

  @override
  String get voiceConsentBody =>
      'Votre voix est transformée en texte pour vous répondre. L\'audio n\'est pas gardé.';

  @override
  String get accept => 'J\'accepte';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get voiceLater => 'Vous pouvez toujours écrire, sans la voix.';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get serverInfo => 'Information';

  @override
  String get infoUnavailable => 'Information indisponible (pas de réseau).';

  @override
  String get whereLive => 'Où habitez-vous ?';

  @override
  String get whereLiveHelp =>
      'Facultatif. Gardé seulement sur ce téléphone. Sert à orienter votre question vers les conseillers de votre zone.';

  @override
  String get skip => 'Passer';

  @override
  String get searchHint => 'Rechercher…';

  @override
  String get noSite => 'Non choisi';

  @override
  String get mineEmpty => 'Aucune question envoyée à un conseiller.';

  @override
  String get mineNote =>
      'Seul un numéro est gardé ici, jamais le texte de vos questions.';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusAnswered => 'Répondu';

  @override
  String get statusUnknown => 'Introuvable';

  @override
  String get counselorAnswer => 'Réponse du conseiller';

  @override
  String get delete => 'Effacer';

  @override
  String get deleteAll => 'Tout effacer';

  @override
  String get deleteConfirm => 'Effacer cette question ?';

  @override
  String get deleteAllConfirm => 'Effacer toutes vos questions ?';

  @override
  String get deleted => 'Effacé';

  @override
  String get cancel => 'Annuler';

  @override
  String get refresh => 'Actualiser';

  @override
  String askedOn(String date) {
    return 'Envoyée le $date';
  }

  @override
  String get menuUnavailable => 'Pas d\'information pour le moment.';

  @override
  String get errorNetwork => 'Pas de connexion. Réessayez.';

  @override
  String get errorRateLimited => 'Trop de questions. Réessayez plus tard.';

  @override
  String get errorConsent => 'Acceptez d\'abord l\'usage de la voix.';

  @override
  String get errorOther => 'Un problème est survenu. Réessayez.';

  @override
  String get retry => 'Réessayer';

  @override
  String get micPermission =>
      'FANILO a besoin du micro pour entendre votre question.';

  @override
  String get micDenied => 'Micro refusé. Vous pouvez écrire votre question.';

  @override
  String get settings => 'Réglages';

  @override
  String get language => 'Langue';

  @override
  String get voiceOn => 'Voix : acceptée';

  @override
  String get voiceOff => 'Voix : non acceptée';

  @override
  String get withdrawConsent => 'Retirer l\'accord';

  @override
  String get place => 'Lieu';

  @override
  String get unreviewedMg =>
      'Textes malgaches à relire par des locuteurs natifs.';

  @override
  String get close => 'Fermer';

  @override
  String get aboutAnonymous => 'Sans compte';

  @override
  String get newAnswer => 'Vous avez une réponse';

  @override
  String get see => 'Voir';

  @override
  String get newLabel => 'Nouveau';

  @override
  String get serverUnreachable => 'Impossible de joindre le serveur';

  @override
  String checkedAt(String time) {
    return 'Vérifié à $time';
  }

  @override
  String get weUnderstood => 'Nous avons compris :';

  @override
  String get voiceNotTranscribed => 'Votre voix n\'a pas pu être transcrite.';

  @override
  String get voiceNotTranscribedFollow =>
      'Votre question est quand même transmise à un conseiller. La réponse sera dans « Mes questions ».';

  @override
  String get voiceNotTranscribedRetry =>
      'Réessayez, ou écrivez votre question.';

  @override
  String get isThisWhatYouSaid => 'Est-ce bien ce que vous avez dit ?';

  @override
  String get yes => 'Oui';

  @override
  String get noWrite => 'Non, je l\'écris';

  @override
  String get voiceNotUnderstood => 'Votre voix n\'a pas été bien comprise.';

  @override
  String get retryVoice => 'Réessayer';

  @override
  String get writeQuestion => 'Écrire la question';

  @override
  String get voiceWait => 'Nous écoutons votre question…';

  @override
  String get goTo => 'Allez à :';

  @override
  String get kindHospital => 'Hôpital de référence';

  @override
  String get kindCsb => 'Centre de santé';

  @override
  String get triageUrgent => 'Urgent';

  @override
  String get triageFollowUp => 'À suivre';

  @override
  String get triageInfo => 'Information';

  @override
  String get showCode => 'Montrez ce code au centre de santé';

  @override
  String get visitExpected => 'Le centre vous attend';

  @override
  String get visitCame => 'Votre venue est enregistrée';

  @override
  String get visitNoShow => 'Vous n\'êtes pas encore venue : allez-y si besoin';
}
