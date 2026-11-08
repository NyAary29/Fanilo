import 'enums.dart';

/// Transitions de référence autorisées (contrat, section 7).
///
/// - `proposed` → `accepted` ou `not_completed`
/// - `accepted` → `arrived`, `transferred` ou `not_completed`
/// - `transferred` → `arrived` ou `not_completed`
///
/// `arrived` et `not_completed` sont terminaux. `not_completed` exige un motif.
class ReferralRules {
  const ReferralRules._();

  static const Map<ReferralStatus, Set<ReferralStatus>> _allowed = {
    ReferralStatus.proposed: {
      ReferralStatus.accepted,
      ReferralStatus.notCompleted,
    },
    ReferralStatus.accepted: {
      ReferralStatus.arrived,
      ReferralStatus.transferred,
      ReferralStatus.notCompleted,
    },
    ReferralStatus.transferred: {
      ReferralStatus.arrived,
      ReferralStatus.notCompleted,
    },
  };

  static Set<ReferralStatus> allowedFrom(ReferralStatus from) =>
      _allowed[from] ?? const {};

  static bool canTransition(ReferralStatus from, ReferralStatus to) =>
      allowedFrom(from).contains(to);

  static bool requiresReason(ReferralStatus to) =>
      to == ReferralStatus.notCompleted;

  /// Lève [ReferralTransitionException] si la transition est invalide.
  static void validate(ReferralStatus from, ReferralStatus to, {String? reason}) {
    if (!canTransition(from, to)) {
      throw ReferralTransitionException(
          'Transition interdite : ${from.wire} → ${to.wire}');
    }
    if (requiresReason(to) && (reason == null || reason.trim().isEmpty)) {
      throw const ReferralTransitionException(
          'Un motif est obligatoire pour « non aboutie ».');
    }
  }
}

class ReferralTransitionException implements Exception {
  const ReferralTransitionException(this.message);
  final String message;
  @override
  String toString() => message;
}
