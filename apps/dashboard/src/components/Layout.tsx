import { NavLink, Outlet } from 'react-router-dom';
import { useApiContext } from '../api/ApiProvider';
import { useAuth } from '../auth/AuthContext';
import { ROLE_LABELS, SECTION_LABELS, SECTION_PATHS, sectionsFor } from '../auth/permissions';
import { Footer } from './Footer';

export function Layout() {
  const { user, logout } = useAuth();
  const { isMock } = useApiContext();
  // Navigation filtrée par rôle : ergonomique seulement, l'API reste l'autorité.
  const sections = sectionsFor(user);

  return (
    <div className="app">
      <a className="skip-link" href="#contenu">
        Aller au contenu
      </a>
      <header className="app-header">
        <div className="brand">
          <span className="brand-name">FANILO</span>
          <span className="brand-sub">Tableau de bord</span>
        </div>
        {user && (
          <div className="user-box">
            <span>
              <span className="mono">{user.login}</span> · {ROLE_LABELS[user.role]}
            </span>
            <button type="button" className="btn btn-secondary" onClick={() => void logout()}>
              Se déconnecter
            </button>
          </div>
        )}
      </header>
      {isMock && (
        <div className="mock-banner" role="note">
          Mode démonstration : données fictives, aucun backend contacté.
        </div>
      )}
      {sections.length > 0 && (
        <nav className="app-nav" aria-label="Navigation principale">
          <ul>
            {sections.map((section) => (
              <li key={section}>
                <NavLink to={SECTION_PATHS[section]}>{SECTION_LABELS[section]}</NavLink>
              </li>
            ))}
          </ul>
        </nav>
      )}
      <main id="contenu" className="app-main" tabIndex={-1}>
        <Outlet />
      </main>
      <Footer />
    </div>
  );
}
