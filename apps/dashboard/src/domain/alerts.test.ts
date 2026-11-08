import { describe, expect, it } from 'vitest';
import { isAlertOverdue } from './alerts';

const now = new Date('2026-11-08T12:00:00Z');
const past = '2026-11-08T11:00:00Z';
const future = '2026-11-08T13:00:00Z';

describe('isAlertOverdue', () => {
  it('vrai si échéance dépassée sans accusé de réception', () => {
    expect(isAlertOverdue({ status: 'open', due_at: past, acknowledged_at: null }, now)).toBe(true);
    expect(isAlertOverdue({ status: 'escalated', due_at: past, acknowledged_at: null }, now)).toBe(true);
  });
  it('faux si acquittée, close ou non échue', () => {
    expect(isAlertOverdue({ status: 'acknowledged', due_at: past, acknowledged_at: past }, now)).toBe(false);
    expect(isAlertOverdue({ status: 'resolved', due_at: past, acknowledged_at: null }, now)).toBe(false);
    expect(isAlertOverdue({ status: 'open', due_at: future, acknowledged_at: null }, now)).toBe(false);
  });
});
