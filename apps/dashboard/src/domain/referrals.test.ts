import { describe, expect, it } from 'vitest';
import { REFERRAL_STATUSES, type ReferralStatus } from '../api/types';
import { allowedReferralTransitions, isTerminalReferralStatus, validateReferralTransition } from './referrals';

// Matrice du contrat §7, écrite indépendamment de l'implémentation.
const EXPECTED: Record<ReferralStatus, ReferralStatus[]> = {
  proposed: ['accepted', 'not_completed'],
  accepted: ['arrived', 'transferred', 'not_completed'],
  transferred: ['arrived', 'not_completed'],
  arrived: [],
  not_completed: [],
};

describe('machine à états des références', () => {
  for (const from of REFERRAL_STATUSES) {
    for (const to of REFERRAL_STATUSES) {
      const allowed = EXPECTED[from].includes(to);
      it(`${from} → ${to} : ${allowed ? 'autorisée' : 'interdite'}`, () => {
        expect(allowedReferralTransitions(from).includes(to)).toBe(allowed);
        const error = validateReferralTransition(from, to, 'motif');
        if (allowed) expect(error).toBeNull();
        else expect(error).toMatch(/Transition interdite/);
      });
    }
  }

  it('exige un motif non vide pour not_completed', () => {
    expect(validateReferralTransition('proposed', 'not_completed', undefined)).toMatch(/motif est obligatoire/);
    expect(validateReferralTransition('accepted', 'not_completed', '   ')).toMatch(/motif est obligatoire/);
    expect(validateReferralTransition('transferred', 'not_completed', 'Transport indisponible')).toBeNull();
  });

  it('arrived et not_completed sont terminaux', () => {
    expect(isTerminalReferralStatus('arrived')).toBe(true);
    expect(isTerminalReferralStatus('not_completed')).toBe(true);
    expect(isTerminalReferralStatus('proposed')).toBe(false);
  });
});
