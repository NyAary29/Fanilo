import { useMutation, useQuery } from '@tanstack/react-query';
import { Baby, Bell, BookOpen, Home, Mic, Square, User, UserRound } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import { useApi } from '../api/ApiProvider';
import type { AskModule, AskResponse, MenuItem } from '../api/types';
import { Badge } from '../components/Badge';
import { DemoBanner } from '../components/DemoBanner';
import { LogoMark } from '../components/Logo';
import { errorMessage, QueryState } from '../components/QueryState';
import { SEVERITY_LABELS } from '../domain/alerts';

const ACTION_LABELS: Record<string, string> = {
  refer_community_agent: "Orienter vers l'agent communautaire",
  transfer_counselor: 'Transférer à un conseiller',
  refer_csb: 'Orienter vers le CSB',
  refer_reference_facility: 'Orienter vers une structure de référence',
};

const OUTCOME_LABELS: Record<AskResponse['outcome'], string> = {
  answer: 'Réponse depuis un contenu approuvé',
  danger_sign: 'Signe de danger : orientation et alerte',
  fallback: 'Transfert à un conseiller humain',
};

type Mode = 'text' | 'signs';

/**
 * Assistant vocal : reproduit en local ce que vit une femme ou une adolescente au
 * téléphone (micro, menu à touches RENY / TANORA) et ce que l'agent saisit (signes).
 * Les questions suivent la vraie chaîne de décision (`POST /interactions/ask`) :
 * journalisées, alertes possibles, revue par un conseiller si nécessaire.
 * Aucune bénéficiaire n'est désignée (question anonyme, comme sur TANORA).
 */
export function SimulatorPage() {
  const api = useApi();
  const [module, setModule] = useState<AskModule>('reny');
  const [mode, setMode] = useState<Mode>('text');
  const [text, setText] = useState('');
  const [signs, setSigns] = useState<string[]>([]);
  const [selected, setSelected] = useState<MenuItem | null>(null);

  const menu = useQuery({ queryKey: ['voice-menu', module], queryFn: () => api.getVoiceMenu(module, 'mg') });
  const signCodes = useQuery({ queryKey: ['sign-codes', module], queryFn: () => api.getSignCodes(module) });
  const ask = useMutation({
    mutationFn: (input: { kind: 'text' } | { kind: 'signs' } | { kind: 'voice'; audio: Blob }) => {
      if (input.kind === 'voice') return api.askAudio(input.audio, module);
      if (input.kind === 'signs') return api.ask({ module, sign_codes: signs });
      return api.ask({ module, text: text.trim() });
    },
    onMutate: () => setSelected(null),
  });

  const chooseModule = (m: AskModule) => {
    setModule(m);
    setSigns([]);
    setSelected(null);
    ask.reset();
  };

  return (
    <section aria-labelledby="sim-title" className="stack">
      <div className="page-head">
        <div>
          <h1 id="sim-title">Assistant vocal</h1>
          <p className="subtitle">
            Ce que vit une femme ou une adolescente au téléphone. Les questions suivent la vraie chaîne de décision.
          </p>
        </div>
      </div>

      <div className="voice-layout">
        <div className="phone" aria-label="Téléphone simulé">
          <div className="phone-screen">
            <div className="phone-head">
              <span className="brand-name">
                <LogoMark size={30} /> FANILO
              </span>
              <Bell size={20} aria-hidden="true" />
            </div>
            <div className="greet">
              <strong>Salama !</strong>
              <span>Miaraha manontany izay tianao ho fantatra.</span>
            </div>

            <VoiceRecorder disabled={ask.isPending} onRecorded={(audio) => ask.mutate({ kind: 'voice', audio })} />

            <div className="module-cards" role="group" aria-label="Module">
              <button type="button" className="module-card reny" aria-pressed={module === 'reny'} onClick={() => chooseModule('reny')}>
                <span className="emoji">
                  <Baby size={28} aria-hidden="true" />
                </span>
                <strong>RENY</strong>
                <span>Fahasalamana mandritra ny vohoka · Grossesse</span>
              </button>
              <button type="button" className="module-card tanora" aria-pressed={module === 'tanora'} onClick={() => chooseModule('tanora')}>
                <span className="emoji">
                  <UserRound size={28} aria-hidden="true" />
                </span>
                <strong>TANORA</strong>
                <span>Fahasalamana ho an&apos;ny zatovo · Adolescentes</span>
              </button>
            </div>

            <QueryState isPending={menu.isPending} error={menu.error}>
              {menu.data && menu.data.items.length === 0 && <p className="muted small">Aucun contenu publié pour ce menu.</p>}
              <ol className="keypad" aria-label="Menu vocal">
                {menu.data?.items.map((item) => (
                  <li key={item.key}>
                    <button
                      type="button"
                      className="btn keypad-btn"
                      onClick={() => {
                        ask.reset();
                        setSelected(item);
                      }}
                    >
                      <span className="keypad-key" aria-hidden="true">
                        {item.key}
                      </span>
                      {item.title}
                    </button>
                  </li>
                ))}
              </ol>
            </QueryState>

            {selected && (
              <div className="answer stack-sm" aria-live="polite">
                <DemoBanner isDemo={selected.status !== 'validated'} />
                <h2 className="h3">
                  Touche {selected.key} · {selected.title}
                </h2>
                <p className="content-body">{selected.body}</p>
                {selected.audio_url && <audio controls src={selected.audio_url} />}
              </div>
            )}
            {ask.isPending && <p aria-live="polite">Analyse en cours…</p>}
            {ask.error && (
              <p className="error" role="alert">
                {errorMessage(ask.error)}
              </p>
            )}
            {ask.data && <AskResult result={ask.data} />}

            <div className="phone-nav" aria-hidden="true">
              <span className="on">
                <Home size={18} /> Trano
              </span>
              <span>
                <BookOpen size={18} /> Fampahalalana
              </span>
              <span>
                <User size={18} /> Kaonty
              </span>
            </div>
          </div>
        </div>

        <div className="stack">
          <div className="panel stack">
            <div className="panel-head">
              <h2>Poser une question autrement</h2>
            </div>
            <div className="segmented" role="tablist" aria-label="Mode de saisie">
              {(
                [
                  ['text', 'Question écrite'],
                  ['signs', 'Signes (AC)'],
                ] as const
              ).map(([value, label]) => (
                <button key={value} type="button" role="tab" aria-selected={mode === value} onClick={() => setMode(value)}>
                  {label}
                </button>
              ))}
            </div>

            {mode === 'text' && (
              <form
                className="stack-sm"
                onSubmit={(e) => {
                  e.preventDefault();
                  if (text.trim()) ask.mutate({ kind: 'text' });
                }}
              >
                <div className="field">
                  <label htmlFor="sim-text">Question (malgache ou français), telle que transcrite</label>
                  <textarea
                    id="sim-text"
                    rows={3}
                    maxLength={2000}
                    placeholder="Ex. : Rahoviana ny fizahana vohoka manaraka ?"
                    value={text}
                    onChange={(e) => setText(e.target.value)}
                  />
                </div>
                <div>
                  <button type="submit" className="btn btn-primary" disabled={ask.isPending || !text.trim()}>
                    Envoyer la question
                  </button>
                </div>
              </form>
            )}

            {mode === 'signs' && (
              <QueryState isPending={signCodes.isPending} error={signCodes.error}>
                <DemoBanner isDemo={!!signCodes.data?.is_demo} />
                <fieldset className="stack-sm sign-list">
                  <legend>Signes constatés (liste fermée et versionnée)</legend>
                  {signCodes.data?.items.map((sign) => (
                    <label key={sign.code} className="radio">
                      <input
                        type="checkbox"
                        checked={signs.includes(sign.code)}
                        onChange={(e) =>
                          setSigns((prev) => (e.target.checked ? [...prev, sign.code] : prev.filter((c) => c !== sign.code)))
                        }
                      />
                      {sign.label_mg ?? sign.label_fr}
                    </label>
                  ))}
                </fieldset>
                <div>
                  <button type="button" className="btn btn-danger" disabled={ask.isPending || signs.length === 0} onClick={() => ask.mutate({ kind: 'signs' })}>
                    Signaler
                  </button>
                </div>
              </QueryState>
            )}
          </div>

          <div className="panel stack-sm">
            <h2 className="h3">Comment ça marche ?</h2>
            <ol className="steps">
              <li>
                <span>Choisissez RENY (grossesse) ou TANORA (adolescentes).</span>
              </li>
              <li>
                <span>Appuyez sur le micro et parlez, tapez une touche du menu, ou écrivez la question.</span>
              </li>
              <li>
                <span>
                  FANILO répond <strong>uniquement</strong> avec un contenu validé. Sinon, la question part chez un conseiller
                  (« Questions des femmes »).
                </span>
              </li>
              <li>
                <span>Un signe de danger crée une alerte au CSB, à suivre dans « Alertes ».</span>
              </li>
            </ol>
            <p className="muted xs">
              La reconnaissance vocale n&apos;est active que si un modèle est configuré ; sinon, la question orale part chez un
              conseiller.
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}

function AskResult({ result }: { result: AskResponse }) {
  return (
    <div className="answer stack-sm" aria-live="polite">
      <DemoBanner isDemo={result.is_demo} />
      <h2 className="h3">
        {OUTCOME_LABELS[result.outcome]}{' '}
        {result.severity && <Badge tone={result.severity === 'critical' ? 'danger' : 'warning'}>{SEVERITY_LABELS[result.severity]}</Badge>}
      </h2>
      {result.transcript !== null && (
        <blockquote className="transcript">
          {result.transcript || <span className="muted">Transcription vide.</span>}
          {result.transcript_needs_review && <p className="small warning-text">Transcription automatique à vérifier.</p>}
        </blockquote>
      )}
      {result.content && (
        <div>
          <strong>{result.content.title}</strong>
          <p className="content-body">{result.content.body}</p>
        </div>
      )}
      {result.actions.length > 0 && (
        <ul>
          {result.actions.map((a) => (
            <li key={a}>{ACTION_LABELS[a] ?? a}</li>
          ))}
        </ul>
      )}
      {result.alert_id && (
        <p className="notice">
          Alerte créée et transmise au destinataire désigné. Elle reste <strong>en attente d&apos;accusé de réception</strong> :
          aucune prise en charge n&apos;est garantie tant qu&apos;un professionnel ne l&apos;a pas confirmée.
        </p>
      )}
      <p className="small">
        <strong>{result.disclaimer}</strong>
      </p>
    </div>
  );
}

function VoiceRecorder({ onRecorded, disabled }: { onRecorded: (audio: Blob) => void; disabled: boolean }) {
  const [recording, setRecording] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const recorder = useRef<MediaRecorder | null>(null);

  useEffect(() => () => recorder.current?.stream.getTracks().forEach((t) => t.stop()), []);

  const start = async () => {
    setError(null);
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      setError("L'enregistrement audio n'est pas disponible dans ce navigateur.");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const chunks: Blob[] = [];
      const rec = new MediaRecorder(stream);
      rec.ondataavailable = (e) => chunks.push(e.data);
      rec.onstop = () => {
        stream.getTracks().forEach((t) => t.stop());
        onRecorded(new Blob(chunks, { type: rec.mimeType || 'audio/webm' }));
      };
      recorder.current = rec;
      rec.start();
      setRecording(true);
    } catch {
      setError('Accès au micro refusé ou impossible.');
    }
  };

  const stop = () => {
    recorder.current?.stop();
    setRecording(false);
  };

  return (
    <div className="mic-wrap">
      <button
        type="button"
        className={`mic${recording ? ' recording' : ''}`}
        disabled={disabled && !recording}
        onClick={() => (recording ? stop() : void start())}
        aria-label={recording ? 'Arrêter et envoyer' : 'Enregistrer une question'}
      >
        {recording ? <Square size={36} aria-hidden="true" /> : <Mic size={44} aria-hidden="true" />}
      </button>
      <span className="mic-label">{recording ? 'Miteny… (appuyez pour envoyer)' : 'Tsindrio ary miteny'}</span>
      <span className="muted xs">Appuyez et parlez · l&apos;audio n&apos;est jamais conservé</span>
      {error && (
        <p className="error small" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
