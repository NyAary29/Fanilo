import { CheckCircle2 } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useApiContext } from '../api/ApiProvider';
import { ApiError } from '../api/client';
import { useAuth } from '../auth/AuthContext';
import { homePathFor } from '../auth/permissions';
import { Footer } from '../components/Footer';
import { Brand } from '../components/Logo';
import { errorMessage } from '../components/QueryState';

/**
 * Comptes de démonstration affichés sur l'écran de connexion LOCAL uniquement
 * (VITE_DEMO_ACCOUNTS=true, posé par scripts/dev.sh). Jamais en production.
 */
const DEMO_ACCOUNTS: { login: string; label: string; what: string }[] = [
  { login: 'conseiller', label: 'Conseiller', what: 'Répond aux femmes, classe l’urgence, oriente vers un centre' },
  { login: 'chef.csb.a', label: 'Chef du CSB', what: 'Responsable du centre : suit les femmes orientées' },
  { login: 'responsable', label: 'Responsable clinique', what: 'Valide les messages de santé' },
  { login: 'admin', label: 'Administrateur', what: 'Crée les comptes et les centres' },
];
const DEMO_PASSWORD = 'fanilo-demo-2026';
const showDemoAccounts = import.meta.env.VITE_DEMO_ACCOUNTS === 'true';

export function LoginPage() {
  const { status, user, notice, login } = useAuth();
  const { isMock } = useApiContext();
  const location = useLocation();
  const [loginValue, setLoginValue] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  if (status === 'authenticated' && user) {
    const from = (location.state as { from?: string } | null)?.from;
    return <Navigate to={from && from !== '/connexion' ? from : homePathFor(user)} replace />;
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(loginValue.trim(), password);
    } catch (err) {
      setError(err instanceof ApiError && err.status === 401 ? 'Identifiant ou mot de passe incorrect.' : errorMessage(err));
    } finally {
      setSubmitting(false);
      setPassword('');
    }
  }

  return (
    <div className="login-page">
      <section className="login-hero" aria-label="Présentation">
        <div className="row" style={{ gap: 'var(--space-3)' }}>
          <Brand light tagline={false} />
        </div>
        <p className="tagline">Fahasalamana ho an&apos;ny rehetra</p>
        <h2>Une santé accessible, pour chaque femme et chaque fille, par la voix, en malgache.</h2>
        <ul>
          {['Suivi des grossesses et rappels de CPN', 'Signes de danger et alertes au CSB', 'Références suivies jusqu\'à l\'arrivée', 'Fonctionne hors connexion'].map((t) => (
            <li key={t}>
              <CheckCircle2 size={22} aria-hidden="true" /> {t}
            </li>
          ))}
        </ul>
      </section>
      <div className="login-main" style={{ flexDirection: 'column' }}>
        <main id="contenu" className="login-card">
          <form className="panel stack" onSubmit={handleSubmit} aria-labelledby="login-title">
            <div>
              <h1 id="login-title">Connexion</h1>
              <p className="muted">Entrez votre identifiant et votre mot de passe.</p>
            </div>
            {notice && (
              <p className="notice" role="status">
                {notice}
              </p>
            )}
            <div className="field">
              <label htmlFor="login">Identifiant</label>
              <input id="login" name="login" autoComplete="username" required value={loginValue} onChange={(e) => setLoginValue(e.target.value)} />
            </div>
            <div className="field">
              <label htmlFor="password">Mot de passe</label>
              <input
                id="password"
                name="password"
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>
            {error && (
              <p className="error" role="alert">
                {error}
              </p>
            )}
            <button type="submit" className="btn btn-primary btn-lg" disabled={submitting || status === 'loading'}>
              {submitting ? 'Connexion…' : 'Se connecter'}
            </button>
            {isMock && (
              <p className="muted small">
                Mode démonstration : comptes fictifs <span className="mono">chef.csb</span>, <span className="mono">conseiller</span>,{' '}
                <span className="mono">responsable</span>, <span className="mono">admin</span>, <span className="mono">donnees</span>… mot de passe{' '}
                <span className="mono">demo</span>.
              </p>
            )}
          </form>
          {showDemoAccounts && !isMock && (
            <div className="panel stack-sm" style={{ marginTop: 'var(--space-4)' }}>
              <h2 className="h3">Comptes de démonstration</h2>
              <p className="muted small">
                Cliquez sur un rôle pour remplir le formulaire (mot de passe <span className="mono">{DEMO_PASSWORD}</span>).
              </p>
              <div className="stack-sm">
                {DEMO_ACCOUNTS.map((a) => (
                  <button
                    key={a.login}
                    type="button"
                    className="btn btn-secondary btn-block"
                    style={{ justifyContent: 'space-between', textAlign: 'left' }}
                    onClick={() => {
                      setLoginValue(a.login);
                      setPassword(DEMO_PASSWORD);
                    }}
                  >
                    <span>{a.label}</span>
                    <span className="muted xs" style={{ fontWeight: 600 }}>
                      {a.what}
                    </span>
                  </button>
                ))}
                <p className="muted xs">
                  L&apos;agent communautaire (<span className="mono">ac.a1</span>) utilise l&apos;application mobile. Les femmes
                  utilisent l&apos;application « Femmes », sans compte.
                </p>
              </div>
            </div>
          )}
        </main>
        <Footer />
      </div>
    </div>
  );
}
