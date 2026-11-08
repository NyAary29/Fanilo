import type { ReferralStatus } from '../api/types';

/**
 * Machine à états des références (contrat §7).
 *
 * Copie côté client UNIQUEMENT pour l'ergonomie (ne proposer que les boutons utiles).
 * Le SERVEUR FAIT FOI : il renvoie 409 pour toute transition refusée, et l'interface
 * affiche alors l'erreur et recharge l'état serveur.
 */
export const REFERRAL_TRANSITIONS: Readonly<Record<ReferralStatus, readonly ReferralStatus[]>> = {
  proposed: ['accepted', 'not_completed'],
  accepted: ['arrived', 'transferred', 'not_completed'],
  transferred: ['arrived', 'not_completed'],
  arrived: [],
  not_completed: [],
};

export const REFERRAL_STATUS_LABELS: Readonly<Record<ReferralStatus, string>> = {
  proposed: 'Proposée',
  accepted: 'Acceptée',
  arrived: 'Arrivée',
  transferred: 'Transférée',
  not_completed: 'Non aboutie',
};

export function allowedReferralTransitions(from: ReferralStatus): readonly ReferralStatus[] {
  return REFERRAL_TRANSITIONS[from];
}

export function isTerminalReferralStatus(status: ReferralStatus): boolean {
  return REFERRAL_TRANSITIONS[status].length === 0;
}

/** Une référence « en attente » n'a pas atteint un état terminal. */
export function isPendingReferral(status: ReferralStatus): boolean {
  return !isTerminalReferralStatus(status);
}

/** Renvoie un message d'erreur en français, ou null si la transition est acceptable. */
export function validateReferralTransition(
  from: ReferralStatus,
  to: ReferralStatus,
  reason: string | undefined,
): string | null {
  if (!REFERRAL_TRANSITIONS[from].includes(to)) {
    return `Transition interdite : « ${REFERRAL_STATUS_LABELS[from]} » vers « ${REFERRAL_STATUS_LABELS[to]} ».`;
  }
  if (to === 'not_completed' && !reason?.trim()) {
    return 'Le motif est obligatoire pour une référence non aboutie.';
  }
  return null;
}
