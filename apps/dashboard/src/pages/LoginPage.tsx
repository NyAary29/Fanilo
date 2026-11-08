import { useState, type FormEvent } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { useApiContext } from '../api/ApiProvider';
import { ApiError } from '../api/client';
import { useAuth } from '../auth/AuthContext';
import { homePathFor } from '../auth/permissions';
import { Footer } from '../components/Footer';
import { errorMessage } from '../components/QueryState';

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
    <div className="app login-page">
      <main id="contenu" className="login-main">
        <form className="panel login-card stack" onSubmit={handleSubmit} aria-labelledby="login-title">
          <h1 id="login-title">FANILO — Connexion</h1>
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
          <button type="submit" className="btn btn-primary" disabled={submitting || status === 'loading'}>
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
      </main>
      <Footer />
    </div>
  );
}
