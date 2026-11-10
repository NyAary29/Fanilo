import { useId, useMemo, useState } from 'react';
import type { MonthActivity } from '../api/types';

const MONTHS_FR = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];

export interface Series {
  key: keyof Omit<MonthActivity, 'month'>;
  label: string;
  color: string;
  dashed?: boolean;
  marker: 'circle' | 'square';
}

export const ACTIVITY_SERIES: Series[] = [
  { key: 'pregnancies', label: 'Grossesses enregistrées', color: 'var(--series-1)', marker: 'circle' },
  { key: 'alerts', label: 'Alertes signe de danger', color: 'var(--series-2)', dashed: true, marker: 'square' },
];

export function monthLabel(month: string): string {
  const m = Number(month.slice(5, 7));
  return MONTHS_FR[m - 1] ?? month;
}

function niceMax(value: number): number {
  if (value <= 4) return 4;
  const pow = 10 ** Math.floor(Math.log10(value));
  const step = [1, 2, 2.5, 5, 10].find((s) => (s * pow * 4) >= value) ?? 10;
  return step * pow * 4;
}

function Marker({ shape, x, y, color }: { shape: Series['marker']; x: number; y: number; color: string }) {
  return shape === 'square' ? (
    <rect x={x - 4.5} y={y - 4.5} width={9} height={9} rx={2} fill={color} stroke="#fff" strokeWidth={2} />
  ) : (
    <circle cx={x} cy={y} r={5} fill={color} stroke="#fff" strokeWidth={2} />
  );
}

/**
 * Courbes mensuelles (même unité : un nombre d'événements, donc un seul axe).
 * Identité jamais portée par la seule couleur : légende, ligne pleine/pointillée,
 * marqueurs rond/carré, étiquettes directes en fin de courbe ; survol = info-bulle ;
 * tableau de données disponible.
 */
export function ActivityChart({ months, series = ACTIVITY_SERIES }: { months: MonthActivity[]; series?: Series[] }) {
  const [hover, setHover] = useState<number | null>(null);
  const [showTable, setShowTable] = useState(false);
  const titleId = useId();
  const W = 640;
  const H = 260;
  const pad = { top: 16, right: 120, bottom: 32, left: 40 };
  const innerW = W - pad.left - pad.right;
  const innerH = H - pad.top - pad.bottom;
  const max = useMemo(() => niceMax(Math.max(1, ...months.flatMap((m) => series.map((s) => m[s.key])))), [months, series]);
  const x = (i: number) => pad.left + (months.length <= 1 ? innerW / 2 : (i * innerW) / (months.length - 1));
  const y = (v: number) => pad.top + innerH - (v / max) * innerH;
  const ticks = [0, max / 4, max / 2, (3 * max) / 4, max];

  return (
    <div className="stack-sm">
      <div className="row">
        <div className="chart-legend" aria-hidden="true">
          {series.map((s) => (
            <span key={s.key} className="key">
              <svg width="26" height="12">
                <line x1="1" y1="6" x2="25" y2="6" stroke={s.color} strokeWidth={2} strokeDasharray={s.dashed ? '5 4' : undefined} />
                <Marker shape={s.marker} x={13} y={6} color={s.color} />
              </svg>
              {s.label}
            </span>
          ))}
        </div>
        <span className="spacer" />
        <button type="button" className="btn-link small" onClick={() => setShowTable((v) => !v)}>
          {showTable ? 'Voir le graphique' : 'Voir les données'}
        </button>
      </div>
      {showTable ? (
        <div className="table-wrap">
          <table className="table">
            <caption className="sr-only">Activité par mois</caption>
            <thead>
              <tr>
                <th scope="col">Mois</th>
                {series.map((s) => (
                  <th key={s.key} scope="col">
                    {s.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {months.map((m) => (
                <tr key={m.month}>
                  <td>{monthLabel(m.month)} {m.month.slice(0, 4)}</td>
                  {series.map((s) => (
                    <td key={s.key}>{m[s.key]}</td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="chart-wrap">
          <svg className="chart" viewBox={`0 0 ${W} ${H}`} role="img" aria-labelledby={titleId} onMouseLeave={() => setHover(null)}>
            <title id={titleId}>
              {series.map((s) => `${s.label} : ${months.map((m) => `${monthLabel(m.month)} ${m[s.key]}`).join(', ')}`).join('. ')}
            </title>
            <g className="grid">
              {ticks.map((t) => (
                <g key={t}>
                  <line x1={pad.left} x2={pad.left + innerW} y1={y(t)} y2={y(t)} />
                  <text x={pad.left - 8} y={y(t) + 4} textAnchor="end">
                    {Math.round(t)}
                  </text>
                </g>
              ))}
            </g>
            {months.map((m, i) => (
              <text key={m.month} x={x(i)} y={H - 8} textAnchor="middle">
                {monthLabel(m.month)}
              </text>
            ))}
            {hover !== null && <line x1={x(hover)} x2={x(hover)} y1={pad.top} y2={pad.top + innerH} stroke="#b9c3bb" strokeWidth={1} />}
            {series.map((s) => {
              const last = months.length - 1;
              return (
                <g key={s.key}>
                  <polyline
                    fill="none"
                    stroke={s.color}
                    strokeWidth={2}
                    strokeLinejoin="round"
                    strokeLinecap="round"
                    strokeDasharray={s.dashed ? '6 5' : undefined}
                    points={months.map((m, i) => `${x(i)},${y(m[s.key])}`).join(' ')}
                  />
                  {months.map((m, i) => (
                    <Marker key={m.month} shape={s.marker} x={x(i)} y={y(m[s.key])} color={s.color} />
                  ))}
                  {last >= 0 && (
                    <text x={x(last) + 10} y={y(months[last]![s.key]) + 4} style={{ fill: 'var(--color-text)', fontWeight: 700 }}>
                      {months[last]![s.key]} · {s.key === 'alerts' ? 'alertes' : 'grossesses'}
                    </text>
                  )}
                </g>
              );
            })}
            {months.map((m, i) => (
              <rect
                key={m.month}
                x={x(i) - innerW / Math.max(2, months.length) / 2}
                y={pad.top}
                width={innerW / Math.max(2, months.length)}
                height={innerH}
                fill="transparent"
                onMouseEnter={() => setHover(i)}
              />
            ))}
          </svg>
          {hover !== null && months[hover] && (
            <div className="chart-tooltip" style={{ left: `${(x(hover) / W) * 100}%`, top: `${(pad.top / H) * 100}%` }}>
              <strong>
                {monthLabel(months[hover]!.month)} {months[hover]!.month.slice(0, 4)}
              </strong>
              {series.map((s) => (
                <div key={s.key}>
                  {s.label} : <strong>{months[hover]![s.key]}</strong>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
