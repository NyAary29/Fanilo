import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../data/api/models.dart';
import '../data/api/public_api.dart';
import '../data/local/local_store.dart';
import 'providers.dart';
import 'widgets/common.dart';

/// État (en mémoire) des questions suivies par un conseiller.
class TicketStatusState {
  const TicketStatusState({
    this.statuses = const {},
    this.checkedAt,
    this.error,
    this.loading = false,
    this.read = const {},
    this.fresh = const {},
    this.announced = const [],
    this.announceSeq = 0,
  });

  /// Dernier état connu par question (jamais écrit sur le téléphone).
  final Map<String, AsyncValue<QuestionStatus>> statuses;

  /// Dernière relecture réussie auprès du serveur.
  final DateTime? checkedAt;

  /// Erreur de connexion de la dernière relecture (hors 404).
  final Object? error;
  final bool loading;

  /// Réponses déjà vues (identifiants seulement, gardés localement).
  final Set<String> read;

  /// Réponses vues pour la première fois pendant cette session (« Vaovao »).
  final Set<String> fresh;

  /// Questions passées à « répondu » lors de la dernière relecture.
  final List<String> announced;
  final int announceSeq;

  bool isAnswered(String id) => statuses[id]?.valueOrNull?.isAnswered ?? false;

  /// Réponses non lues (badge).
  int unreadCount(Iterable<Ticket> tickets) =>
      tickets.where((t) => isAnswered(t.questionId) && !read.contains(t.questionId)).length;

  TicketStatusState copyWith({
    Map<String, AsyncValue<QuestionStatus>>? statuses,
    DateTime? checkedAt,
    Object? error,
    bool clearError = false,
    bool? loading,
    Set<String>? read,
    Set<String>? fresh,
    List<String>? announced,
    int? announceSeq,
  }) =>
      TicketStatusState(
        statuses: statuses ?? this.statuses,
        checkedAt: checkedAt ?? this.checkedAt,
        error: clearError ? null : (error ?? this.error),
        loading: loading ?? this.loading,
        read: read ?? this.read,
        fresh: fresh ?? this.fresh,
        announced: announced ?? this.announced,
        announceSeq: announceSeq ?? this.announceSeq,
      );
}

class TicketStatusController extends StateNotifier<TicketStatusState> {
  TicketStatusController(this._ref)
      : super(TicketStatusState(read: _ref.read(storeProvider).readAnswers));
  final Ref _ref;
  Future<void>? _inflight;

  /// Relit l'état de tous les tickets (un seul appel à la fois).
  Future<void> refresh() => _inflight ??= _refresh().whenComplete(() => _inflight = null);

  Future<void> _refresh() async {
    final tickets = _ref.read(ticketsProvider);
    if (tickets.isEmpty) {
      if (mounted) state = state.copyWith(statuses: {}, clearError: true, checkedAt: DateTime.now());
      return;
    }
    state = state.copyWith(loading: true);
    final api = _ref.read(apiProvider);
    Object? networkError;
    final results = <String, AsyncValue<QuestionStatus>>{};
    await Future.wait(tickets.map((t) async {
      try {
        results[t.questionId] = AsyncValue.data(await api.question(t.questionId, t.token));
      } catch (e, st) {
        final notFound = e is ApiException && e.kind == ApiErrorKind.notFound;
        if (!notFound) networkError ??= e;
        // En cas de coupure, on garde le dernier état connu.
        results[t.questionId] = notFound
            ? AsyncValue.error(e, st)
            : (state.statuses[t.questionId] ?? AsyncValue.error(e, st));
      }
    }));
    if (!mounted) return;
    final newly = [
      for (final t in tickets)
        if ((results[t.questionId]?.valueOrNull?.isAnswered ?? false) &&
            !state.isAnswered(t.questionId) &&
            !state.read.contains(t.questionId))
          t.questionId
    ];
    state = state.copyWith(
      statuses: results,
      loading: false,
      error: networkError,
      clearError: networkError == null,
      checkedAt: networkError == null ? DateTime.now() : null,
      announced: newly,
      announceSeq: newly.isEmpty ? null : state.announceSeq + 1,
    );
  }

  /// « Ny fanontaniako » est affiché : les réponses reçues sont lues.
  Future<void> markAnsweredRead() async {
    final ids = [
      for (final t in _ref.read(ticketsProvider))
        if (state.isAnswered(t.questionId) && !state.read.contains(t.questionId)) t.questionId
    ];
    if (ids.isEmpty) return;
    state = state.copyWith(read: {...state.read, ...ids}, fresh: {...state.fresh, ...ids});
    await _ref.read(storeProvider).markRead(ids);
  }

  void forget(String questionId) {
    state = state.copyWith(
      statuses: {...state.statuses}..remove(questionId),
      read: {...state.read}..remove(questionId),
    );
  }
}

final ticketStatusProvider =
    StateNotifierProvider<TicketStatusController, TicketStatusState>(TicketStatusController.new);

/// Relit l'état des questions : au démarrage, au retour au premier plan, à
/// l'ouverture de « Ny fanontaniako », après l'ajout d'une question et toutes
/// les [AppConfig.pollInterval] tant que l'application est au premier plan.
/// Annonce chaque nouvelle réponse (« Nahazo valiny ianao »).
class TicketStatusPoller extends ConsumerStatefulWidget {
  const TicketStatusPoller({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<TicketStatusPoller> createState() => _TicketStatusPollerState();
}

class _TicketStatusPollerState extends ConsumerState<TicketStatusPoller>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _announced = false;
  late final _controller = ref.read(ticketStatusProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller;
    _startTimer();
    scheduleMicrotask(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.pollInterval, (_) => _refresh());
  }

  /// « Ny fanontaniako » est réellement à l'écran (pas d'écran par-dessus).
  bool get _listVisible =>
      ref.read(tabProvider) == 2 && (ModalRoute.of(context)?.isCurrent ?? true);

  Future<void> _refresh() async {
    if (!mounted) return;
    await _controller.refresh();
    if (mounted && _listVisible) await _controller.markAnsweredRead();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      _startTimer();
      _refresh();
    } else if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _timer?.cancel();
    }
  }

  void _announce() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _announced = true;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('new-answer-snack'),
        duration: const Duration(seconds: 8),
        content: Row(children: [
          const Icon(Icons.mark_chat_unread, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(context.l.newAnswer)),
        ]),
        action: SnackBarAction(
          label: context.l.see,
          textColor: Colors.white,
          onPressed: () {
            ref.read(tabProvider.notifier).state = 2;
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabProvider, (prev, next) {
      if (next == 2 && prev != 2) {
        // La liste est ouverte : l'annonce n'a plus lieu d'être.
        if (_announced) ScaffoldMessenger.maybeOf(context)?.removeCurrentSnackBar();
        _announced = false;
        _refresh();
      }
    });
    ref.listen(ticketsProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) _refresh();
    });
    ref.listen(ticketStatusProvider, (prev, next) {
      if (next.announceSeq != (prev?.announceSeq ?? 0) && next.announced.isNotEmpty) {
        // Annoncé seulement si l'utilisatrice n'est pas déjà sur la liste.
        if (!_listVisible) _announce();
      }
    });
    return widget.child;
  }
}
