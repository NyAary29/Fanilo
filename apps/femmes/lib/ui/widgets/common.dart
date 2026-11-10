import 'package:flutter/material.dart';

import '../../data/api/models.dart';
import '../../data/api/public_api.dart';
import '../../l10n/gen/app_localizations.dart';
import '../screens/emergency_screen.dart';
import '../theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}

/// Bandeau DÉMO : contenu non validé cliniquement.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('demo-banner'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: FaniloColors.demoSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FaniloColors.demo, width: 1.5),
        ),
        child: Row(children: [
          const Icon(Icons.science_outlined, color: FaniloColors.demo),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.l.demoBanner,
                style: const TextStyle(
                    color: FaniloColors.demo, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ]),
      );
}

/// « FANILO ne remplace pas un professionnel de santé. »
class Disclaimer extends StatelessWidget {
  const Disclaimer({super.key, this.text});

  /// Texte renvoyé par l'API (affiché en plus, s'il diffère).
  final String? text;

  @override
  Widget build(BuildContext context) {
    final local = context.l.disclaimer;
    final extra = text != null && text!.isNotEmpty && text != local ? text : null;
    return Padding(
      key: const Key('disclaimer'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 20, color: FaniloColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(extra == null ? local : '$local\n$extra',
              style: const TextStyle(color: FaniloColors.inkSoft, fontSize: 14)),
        ),
      ]),
    );
  }
}

/// Grand bloc rouge : aller au centre de santé sans attendre.
class UrgentBlock extends StatelessWidget {
  const UrgentBlock({super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('urgent-block'),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FaniloColors.alert,
          borderRadius: BorderRadius.circular(20),
          boxShadow: kSoftShadow,
        ),
        child: Column(children: [
          const Icon(Icons.local_hospital, color: Colors.white, size: 56),
          const SizedBox(height: 10),
          Text(context.l.goNow,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, height: 1.25)),
          const SizedBox(height: 10),
          Text(context.l.emergencyCompanion,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// Bouton « Vonjy maika » de la barre d'application, toujours présent.
class EmergencyAction extends StatelessWidget {
  const EmergencyAction({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          label: context.l.emergency,
          child: Material(
            color: FaniloColors.alertSoft,
            shape: const StadiumBorder(side: BorderSide(color: FaniloColors.alert)),
            child: InkWell(
              key: const Key('emergency-button'),
              customBorder: const StadiumBorder(),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const EmergencyScreen())),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.sos, color: FaniloColors.alert, size: 24),
                    const SizedBox(width: 4),
                    Text(context.l.emergency,
                        style: const TextStyle(
                            color: FaniloColors.alertInk,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Ligne « icône + texte court ».
class IconLine extends StatelessWidget {
  const IconLine({super.key, required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: (color ?? FaniloColors.forest).withValues(alpha: 0.12),
                shape: BoxShape.circle),
            child: Icon(icon, color: color ?? FaniloColors.forest, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
}

String moduleTitle(Module m) => m.name.toUpperCase();

String moduleSubtitle(BuildContext context, Module m) =>
    m == Module.reny ? context.l.renySubtitle : context.l.tanoraSubtitle;

Color moduleColor(Module m) => m == Module.reny ? FaniloColors.reny : FaniloColors.tanora;
Color moduleStrong(Module m) =>
    m == Module.reny ? FaniloColors.renyStrong : FaniloColors.tanoraStrong;
Color moduleInk(Module m) => m == Module.reny ? FaniloColors.renyInk : FaniloColors.tanoraInk;

/// Message simple pour une erreur d'API.
String apiErrorMessage(BuildContext context, Object error) {
  final l = context.l;
  if (error is ApiException) {
    return switch (error.kind) {
      ApiErrorKind.network => l.errorNetwork,
      ApiErrorKind.rateLimited => l.errorRateLimited,
      ApiErrorKind.consentRequired => l.errorConsent,
      ApiErrorKind.unavailable => l.menuUnavailable,
      _ => l.errorOther,
    };
  }
  return l.errorOther;
}

String formatDate(DateTime d) {
  final t = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
}

/// Pied commun : avertissement.
class ScreenFooter extends StatelessWidget {
  const ScreenFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 12, bottom: 8),
        child: Disclaimer(),
      );
}
