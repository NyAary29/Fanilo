import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Écran standard : barre de titre, contenu, et mention permanente
/// « FANILO ne remplace pas un professionnel de santé. » en pied de page.
class FaniloScaffold extends StatelessWidget {
  const FaniloScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: SafeArea(bottom: false, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: const DisclaimerFooter(),
    );
  }
}

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.disclaimer,
                  key: const Key('disclaimer'),
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
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
      color: Colors.orange.shade800,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Grande tuile tactile de menu.
class BigTile extends StatelessWidget {
  const BigTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge != null,
                label: Text(badge ?? ''),
                child: Icon(icon, size: 40, color: scheme.primary),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}

class PendingChip extends StatelessWidget {
  const PendingChip({super.key});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.cloud_upload_outlined, size: 18),
        label: Text(context.l10n.pendingSync),
        visualDensity: VisualDensity.compact,
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

String formatDateTime(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${formatDate(iso)} ${two(d.hour)}:${two(d.minute)}';
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
