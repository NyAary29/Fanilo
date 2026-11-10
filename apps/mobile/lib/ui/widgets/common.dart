import 'package:flutter/material.dart';

import '../../domain/follow_up.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Écran standard : barre de titre, contenu, et mention permanente
/// « FANILO ne remplace pas un professionnel de santé. » en pied de page.
///
/// [showDisclaimer] vaut faux pour les onglets de l'écran principal, qui
/// affiche lui-même la mention au-dessus de la barre de navigation.
class FaniloScaffold extends StatelessWidget {
  const FaniloScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showDisclaimer = true,
    this.bottom,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showDisclaimer;

  /// Barre d'action fixe (au-dessus de la mention).
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(bottom: false, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: (showDisclaimer || bottom != null)
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (bottom != null) bottom!,
                if (showDisclaimer) const DisclaimerFooter(),
              ],
            )
          : null,
    );
  }
}

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key, this.safeArea = true});
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: FaniloColors.inkSoft),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.disclaimer,
              key: const Key('disclaimer'),
              style: const TextStyle(fontSize: 12.5, color: FaniloColors.inkSoft),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: FaniloColors.mint,
      child: safeArea ? SafeArea(top: false, child: content) : content,
    );
  }
}

/// Bandeau « DÉMO » très visible.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('demo-banner'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: FaniloColors.demo,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// Carte blanche arrondie à ombre douce.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = FaniloColors.surface,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: kSoftShadow,
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 1.5),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Grande action de l'accueil : pictogramme dans un cercle et libellé court.
class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.background = FaniloColors.forest,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kRadius + 4);
    return Material(
      color: background,
      borderRadius: radius,
      elevation: 0,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground, size: 28),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                      color: foreground, fontSize: 18, fontWeight: FontWeight.w800, height: 1.15)),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!,
                      style: TextStyle(
                          color: foreground.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourci secondaire (Alertes, Références, Conflits…).
class ShortcutTile extends StatelessWidget {
  const ShortcutTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.color = FaniloColors.forest,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badge != null && badge! > 0,
            backgroundColor: FaniloColors.alert,
            label: Text('${badge ?? ''}'),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Pastille « À jour » (vert) ou « À suivre » (orange).
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final FollowUpStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final toFollow = status == FollowUpStatus.toFollow;
    return Container(
      key: Key(toFollow ? 'chip-to-follow' : 'chip-up-to-date'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: toFollow ? FaniloColors.followSoft : FaniloColors.okSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(toFollow ? Icons.schedule : Icons.check_circle,
              size: 16, color: toFollow ? FaniloColors.follow : FaniloColors.ok),
          const SizedBox(width: 4),
          Text(toFollow ? l.statusToFollow : l.statusUpToDate,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: toFollow ? FaniloColors.followInk : FaniloColors.forestDark)),
        ],
      ),
    );
  }
}

/// Avatar à initiales.
class PatientAvatar extends StatelessWidget {
  const PatientAvatar({super.key, required this.name, this.size = 48, this.alert = false});
  final String? name;
  final double size;
  final bool alert;

  static const _tones = [
    Color(0xFFF3D9C4),
    Color(0xFFD7E8D3),
    Color(0xFFF6E3B8),
    Color(0xFFE5D6EC),
    Color(0xFFD2E4EE),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = initialsOf(name);
    final tone = _tones[(name ?? '').codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tone,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(initials,
              style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w800,
                  color: FaniloColors.forestDark)),
        ),
        if (alert)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: FaniloColors.alert,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(Icons.priority_high, color: Colors.white, size: size * 0.22),
            ),
          ),
      ],
    );
  }
}

/// Titre de section avec pictogramme.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: FaniloColors.forest, size: 24),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: FaniloColors.forestDark, fontSize: 19)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

enum NoticeTone { info, ok, warning, alert }

/// Message court avec pictogramme (information, attention, alerte).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.text,
    this.tone = NoticeTone.info,
    this.icon,
    this.title,
    this.action,
    this.textKey,
  });

  final String text;
  final String? title;
  final NoticeTone tone;
  final IconData? icon;
  final Widget? action;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, ic) = switch (tone) {
      NoticeTone.info => (FaniloColors.mint, FaniloColors.forestDark, Icons.info_outline),
      NoticeTone.ok => (FaniloColors.okSoft, FaniloColors.forestDark, Icons.check_circle),
      NoticeTone.warning => (FaniloColors.followSoft, FaniloColors.followInk, Icons.schedule),
      NoticeTone.alert => (FaniloColors.alertSoft, FaniloColors.alertInk, Icons.warning_rounded),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(kRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon ?? ic, color: fg, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(title!,
                          style: TextStyle(
                              color: fg, fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                  Text(text,
                      key: textKey,
                      style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: title == null ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          ]),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: FaniloColors.leafLight),
              const SizedBox(height: 8),
              Text(text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: FaniloColors.inkSoft)),
            ],
          ),
        ),
      );
}

class PendingChip extends StatelessWidget {
  const PendingChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: FaniloColors.followSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_upload_outlined, size: 16, color: FaniloColors.followInk),
          const SizedBox(width: 4),
          Flexible(
            child: Text(context.l10n.pendingSync,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: FaniloColors.followInk)),
          ),
        ]),
      );
}

/// `YYYY-MM-DD` ou ISO 8601 → `JJ/MM/AAAA` (sans dépendre des données de
/// locale d'intl).
String formatDate(String? iso) {
  if (iso == null || iso.length < 10) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final local = iso.length > 10 ? d.toLocal() : d;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}';
}

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

/// `YYYY-MM-DD` → « 12 nov. 2026 ».
String formatDateLong(String? iso) {
  if (iso == null || iso.length < 10) return '—';
  final d = DateTime.tryParse(iso.substring(0, 10));
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String formatDateTime(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${formatDate(iso)} ${two(d.hour)}:${two(d.minute)}';
}

/// Heure seule (« 08:30 ») si [iso] est aujourd'hui, sinon date et heure.
String formatSyncTime(String iso, String today) {
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  final day = d.toIso8601String().substring(0, 10);
  return day == today ? '${two(d.hour)}:${two(d.minute)}' : formatDateTime(iso);
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDialog(BuildContext context, String message) async {
  final l = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message, style: const TextStyle(fontSize: 17)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: Text(l.confirm)),
      ],
    ),
  );
  return result ?? false;
}
