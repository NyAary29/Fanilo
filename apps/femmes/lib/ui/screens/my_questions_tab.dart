import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/models.dart';
import '../../data/api/public_api.dart';
import '../../data/local/local_store.dart';
import '../providers.dart';
import '../ticket_status.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// « Ny fanontaniako » : questions suivies par un conseiller.
///
/// Seuls des tickets (identifiant, jeton, module, date) et les identifiants
/// des réponses déjà vues sont gardés sur le téléphone. L'état et la réponse
/// du conseiller sont relus sur le serveur par [TicketStatusPoller] (voir
/// `ticket_status.dart`) et ne restent qu'en mémoire.
class MyQuestionsTab extends ConsumerStatefulWidget {
  const MyQuestionsTab({super.key});

  @override
  ConsumerState<MyQuestionsTab> createState() => _MyQuestionsTabState();
}

class _MyQuestionsTabState extends ConsumerState<MyQuestionsTab> {
  Future<void> _refresh() async {
    final c = ref.read(ticketStatusProvider.notifier);
    await c.refresh();
    await c.markAnsweredRead();
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.delete_forever, size: 40, color: FaniloColors.alert),
          content: Text(text, style: const TextStyle(fontSize: 18)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l.cancel)),
            FilledButton(
              key: const Key('confirm-delete'),
              style: FilledButton.styleFrom(backgroundColor: FaniloColors.alert),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l.delete),
            ),
          ],
        ),
      ) ??
      false;

  /// Efface sur le serveur puis sur le téléphone. Une question déjà
  /// introuvable (404) est retirée aussi. Renvoie l'erreur éventuelle.
  Future<Object?> _deleteOne(Ticket t) async {
    try {
      await ref.read(apiProvider).deleteQuestion(t.questionId, t.token);
    } on ApiException catch (e) {
      if (e.kind != ApiErrorKind.notFound) return e;
    } catch (e) {
      return e;
    }
    await ref.read(ticketsProvider.notifier).remove(t.questionId);
    ref.read(ticketStatusProvider.notifier).forget(t.questionId);
    return null;
  }

  void _report(Object? error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: error == null ? null : FaniloColors.alertInk,
      content: Text(error == null ? context.l.deleted : apiErrorMessage(context, error)),
    ));
  }

  Future<void> _delete(Ticket t) async {
    if (!await _confirm(context.l.deleteConfirm)) return;
    final error = await _deleteOne(t);
    if (mounted) setState(() {});
    _report(error);
  }

  Future<void> _deleteAll() async {
    if (!await _confirm(context.l.deleteAllConfirm)) return;
    Object? firstError;
    for (final t in List.of(ref.read(ticketsProvider))) {
      firstError ??= await _deleteOne(t);
    }
    if (mounted) setState(() {});
    _report(firstError);
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(ticketsProvider);
    final st = ref.watch(ticketStatusProvider);
    final l = context.l;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const Key('mine-list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Row(children: [
            const Icon(Icons.forum, color: FaniloColors.forest, size: 30),
            const SizedBox(width: 8),
            Expanded(child: Text(l.navMine, style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              key: const Key('refresh-mine'),
              tooltip: l.refresh,
              iconSize: 30,
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, color: FaniloColors.forest),
            ),
          ]),
          IconLine(icon: Icons.lock, text: l.mineNote),
          if (tickets.isNotEmpty) _ConnectionLine(state: st, onRetry: _refresh),
          const SizedBox(height: 6),
          if (tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                const Icon(Icons.inbox, size: 64, color: FaniloColors.leafLight),
                const SizedBox(height: 8),
                Text(l.mineEmpty,
                    key: const Key('mine-empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17)),
              ]),
            ),
          for (final t in tickets)
            _TicketCard(
              ticket: t,
              status: st.statuses[t.questionId],
              isNew: st.fresh.contains(t.questionId),
              onDelete: () => _delete(t),
            ),
          if (tickets.isNotEmpty) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('delete-all'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: FaniloColors.alert,
                  side: const BorderSide(color: FaniloColors.alert, width: 1.5)),
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_sweep, size: 28),
              label: Text(l.deleteAll),
            ),
          ],
          const ScreenFooter(),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard(
      {required this.ticket, required this.status, required this.isNew, required this.onDelete});
  final Ticket ticket;
  final AsyncValue<QuestionStatus>? status;

  /// Réponse reçue depuis l'ouverture de l'application.
  final bool isNew;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final s = status?.valueOrNull;
    final err = status?.error;
    final notFound = err is ApiException && err.kind == ApiErrorKind.notFound;
    final (label, icon, color, bg) = switch ((s, notFound)) {
      (QuestionStatus(isAnswered: true), _) =>
        (l.statusAnswered, Icons.mark_chat_read, FaniloColors.ok, FaniloColors.okSoft),
      (_, true) => (l.statusUnknown, Icons.help_outline, FaniloColors.inkSoft, FaniloColors.mint),
      _ => (l.statusPending, Icons.hourglass_top, FaniloColors.followInk, FaniloColors.followSoft),
    };
    final answered = s?.isAnswered ?? false;
    return Card(
      key: Key('ticket-${ticket.questionId}'),
      // Une question répondue est mise en avant.
      shape: answered
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
              side: const BorderSide(color: FaniloColors.ok, width: 2.5))
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: moduleColor(ticket.module), borderRadius: BorderRadius.circular(20)),
              child: Text(moduleTitle(ticket.module),
                  style: TextStyle(fontWeight: FontWeight.w900, color: moduleInk(ticket.module))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.askedOn(formatDate(ticket.createdAt)),
                  style: const TextStyle(color: FaniloColors.inkSoft, fontSize: 14)),
            ),
            IconButton(
              key: Key('delete-${ticket.questionId}'),
              tooltip: l.delete,
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: FaniloColors.alert),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 6),
                Text(label,
                    key: Key('status-${ticket.questionId}'),
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
              ]),
            ),
            if (s?.triage != null) _TriageChip(id: ticket.questionId, triage: s!.triage!),
            if (isNew && (s?.isAnswered ?? false)) ...[
              Container(
                key: Key('new-${ticket.questionId}'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: FaniloColors.alert, borderRadius: BorderRadius.circular(12)),
                child: Text(l.newLabel,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
              ),
            ],
          ]),
          // Urgent : consigne rouge, aller au centre maintenant.
          if (s?.triage == 'urgent') ...[
            const SizedBox(height: 12),
            Container(
              key: Key('urgent-${ticket.questionId}'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: FaniloColors.alert, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.local_hospital, color: Colors.white, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.goNow,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
          ],
          if (s?.answer != null) ...[
            const SizedBox(height: 12),
            Container(
              key: Key('answer-${ticket.questionId}'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FaniloColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.support_agent, color: FaniloColors.forest, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l.counselorAnswer,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17, color: FaniloColors.forest)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(s!.answer!,
                    style: const TextStyle(
                        fontSize: 20, height: 1.4, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          if (s?.orientation != null) ...[
            const SizedBox(height: 10),
            _OrientationCard(id: ticket.questionId, orientation: s!.orientation!),
          ],
          if (s?.followUpCode != null) ...[
            const SizedBox(height: 10),
            _CodeTicket(id: ticket.questionId, code: s!.followUpCode!),
          ],
          if (s?.followUpStatus != null) ...[
            const SizedBox(height: 10),
            _VisitStatus(id: ticket.questionId, status: s!.followUpStatus!),
          ],
          if (s?.isAnswered ?? false) const Disclaimer(),
        ]),
      ),
    );
  }
}

/// État de la connexion : « Vérifié à HH:mm », ou serveur injoignable avec
/// « Réessayer ».
class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.state, required this.onRetry});
  final TicketStatusState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    String two(int n) => n.toString().padLeft(2, '0');
    final checked = state.checkedAt?.toLocal();
    final checkedText =
        checked == null ? null : l.checkedAt('${two(checked.hour)}:${two(checked.minute)}');
    if (state.error != null) {
      return Container(
        key: const Key('server-unreachable'),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FaniloColors.alertSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FaniloColors.alert),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.cloud_off, color: FaniloColors.alertInk, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l.serverUnreachable,
                  style: const TextStyle(
                      color: FaniloColors.alertInk, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ]),
          if (checkedText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 38),
              child: Text(checkedText, style: const TextStyle(color: FaniloColors.inkSoft)),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('retry-mine'),
            style: FilledButton.styleFrom(backgroundColor: FaniloColors.alert),
            onPressed: state.loading ? null : onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l.retry),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(state.loading ? Icons.sync : Icons.cloud_done, color: FaniloColors.ok, size: 20),
        const SizedBox(width: 8),
        Text(checkedText ?? '…',
            key: const Key('checked-at'),
            style: const TextStyle(color: FaniloColors.inkSoft, fontSize: 14)),
      ]),
    );
  }
}

/// « Mandehana any amin'ny / Allez à : » + structure indiquée par le conseiller.
class _OrientationCard extends StatelessWidget {
  const _OrientationCard({required this.id, required this.orientation});
  final String id;
  final CareOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final o = orientation;
    return Container(
      key: Key('orientation-$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FaniloColors.forest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: kSoftShadow,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(o.isReferenceFacility ? Icons.local_hospital : Icons.health_and_safety,
              color: FaniloColors.alert, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.goTo,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(o.name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, height: 1.2)),
            if (o.place.isNotEmpty)
              Text(o.place, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(o.isReferenceFacility ? l.kindHospital : l.kindCsb,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Classement du conseiller.
class _TriageChip extends StatelessWidget {
  const _TriageChip({required this.id, required this.triage});
  final String id;
  final String triage;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final (label, icon, fg, bg) = switch (triage) {
      'urgent' => (l.triageUrgent, Icons.warning_rounded, Colors.white, FaniloColors.alert),
      'follow_up' => (l.triageFollowUp, Icons.event_repeat, Colors.white, FaniloColors.follow),
      _ => (l.triageInfo, Icons.info, Colors.white, FaniloColors.ok),
    };
    return Container(
      key: Key('triage-$id'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 20),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 16)),
      ]),
    );
  }
}

/// Code à montrer au centre de santé (reconnaissance sans nom).
class _CodeTicket extends StatelessWidget {
  const _CodeTicket({required this.id, required this.code});
  final String id;
  final String code;

  @override
  Widget build(BuildContext context) => Container(
        key: Key('code-$id'),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: FaniloColors.forest, width: 3),
        ),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.confirmation_number, color: FaniloColors.forest, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.l.showCode,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(code,
                style: TextStyle(
                    // Police à chasse fixe d'Android ; ailleurs, police par défaut.
                    fontFamily: Platform.isAndroid ? 'monospace' : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: FaniloColors.forestDark)),
          ),
        ]),
      );
}

/// Suivi par le centre : attendue, venue, pas encore venue.
class _VisitStatus extends StatelessWidget {
  const _VisitStatus({required this.id, required this.status});
  final String id;
  final String status;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final (text, icon, fg, bg) = switch (status) {
      'came' => (l.visitCame, Icons.verified, FaniloColors.ok, FaniloColors.okSoft),
      'no_show' => (l.visitNoShow, Icons.directions_walk, FaniloColors.followInk, FaniloColors.followSoft),
      _ => (l.visitExpected, Icons.schedule, FaniloColors.forest, FaniloColors.mint),
    };
    return Container(
      key: Key('visit-$id'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: fg, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 17)),
        ),
      ]),
    );
  }
}
