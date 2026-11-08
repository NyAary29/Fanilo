import type { Alert, AlertEventType, AlertStatus, Severity } from '../api/types';

export const ALERT_STATUS_LABELS: Readonly<Record<AlertStatus, string>> = {
  open: 'Ouverte',
  acknowledged: 'Acquittée',
  resolved: 'Résolue',
  escalated: 'Escaladée',
  cancelled: 'Annulée',
};

export const SEVERITY_LABELS: Readonly<Record<Severity, string>> = {
  critical: 'Critique',
  urgent: 'Urgente',
  routine: 'Routine',
};

export const ALERT_EVENT_LABELS: Readonly<Record<AlertEventType, string>> = {
  created: 'Créée',
  acknowledged: 'Acquittée',
  escalated: 'Escaladée',
  note: 'Note',
  resolved: 'Résolue',
  cancelled: 'Annulée',
};

/**
 * Une alerte est « en retard » si personne n'en a encore accusé réception
 * et que son échéance `due_at` est dépassée.
 */
export function isAlertOverdue(alert: Pick<Alert, 'status' | 'due_at' | 'acknowledged_at'>, now: Date = new Date()): boolean {
  if (alert.acknowledged_at) return false;
  if (alert.status !== 'open' && alert.status !== 'escalated') return false;
  return new Date(alert.due_at).getTime() < now.getTime();
}

export function canAcknowledgeStatus(status: AlertStatus): boolean {
  return status === 'open' || status === 'escalated';
}

export function canResolveStatus(status: AlertStatus): boolean {
  return status === 'open' || status === 'acknowledged' || status === 'escalated';
}

export function severityTone(severity: Severity): 'danger' | 'warning' | 'neutral' {
  return severity === 'critical' ? 'danger' : severity === 'urgent' ? 'warning' : 'neutral';
}
