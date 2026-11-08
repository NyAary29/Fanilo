const dateTimeFormat = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'short', timeStyle: 'short' });
const dateFormat = new Intl.DateTimeFormat('fr-FR', { dateStyle: 'medium' });

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : dateTimeFormat.format(d);
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : dateFormat.format(d);
}

export function formatPercent(ratio: number): string {
  return `${(ratio * 100).toLocaleString('fr-FR', { maximumFractionDigits: 1 })} %`;
}

/** Identifiant raccourci pour l'affichage (jamais un champ nominatif). */
export function shortId(value: string | null | undefined): string {
  if (!value) return '—';
  return value.slice(-8);
}
