import { useQuery } from '@tanstack/react-query';
import {
  BarChart3,
  Bell,
  Building2,
  CircleHelp,
  FileText,
  HeartPulse,
  LayoutDashboard,
  LogOut,
  Menu,
  MessageCircleQuestion,
  MapPinCheck,
  Mic,
  Route,
  ShieldCheck,
  TriangleAlert,
  UserCog,
  type LucideIcon,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useApi, useApiContext } from '../api/ApiProvider';
import { useAuth } from '../auth/AuthContext';
import { canAccess, ROLE_LABELS, SECTION_LABELS, SECTION_PATHS, sectionsFor, type Section } from '../auth/permissions';
import { Footer } from './Footer';
import { Brand } from './Logo';

export const SECTION_ICONS: Readonly<Record<Section, LucideIcon>> = {
  dashboard: LayoutDashboard,
  patients: HeartPulse,
  alerts: TriangleAlert,
  referrals: Route,
  interactions: MessageCircleQuestion,
  orientations: MapPinCheck,
  simulator: Mic,
  stats: BarChart3,
  contents: FileText,
  users: UserCog,
  sites: Building2,
  audit: ShieldCheck,
};

export function initials(text: string | null | undefined): string {
  const parts = (text ?? '?').replace(/[._-]/g, ' ').trim().split(/\s+/);
  return ((parts[0]?.[0] ?? '?') + (parts[1]?.[0] ?? '')).toUpperCase();
}

export function Layout() {
  const { user, logout } = useAuth();
  const { isMock } = useApiContext();
  const api = useApi();
  const location = useLocation();
  const [open, setOpen] = useState(false);
  // Navigation filtrée par rôle : ergonomique seulement, l'API reste l'autorité.
  const sections = sectionsFor(user);
  const current = sections.find((s) => location.pathname.startsWith(SECTION_PATHS[s]));
  const alertsAllowed = canAccess(user, 'alerts');
  const openAlerts = useQuery({
    queryKey: ['alerts-open-count'],
    queryFn: () => api.listAlerts({ status: 'open', limit: 1 }),
    enabled: alertsAllowed,
    refetchInterval: 60_000,
  });
  const alertCount = openAlerts.data?.total ?? 0;

  useEffect(() => setOpen(false), [location.pathname]);

  return (
    <div className="app">
      <a className="skip-link" href="#contenu">
        Aller au contenu
      </a>
      {open && <div className="sidebar-backdrop" onClick={() => setOpen(false)} aria-hidden="true" />}
      <aside className={`sidebar${open ? ' open' : ''}`} aria-label="Menu">
        <Link to="/" className="sidebar-brand" aria-label="FANILO, accueil">
          <Brand light />
        </Link>
        {sections.length > 0 && (
          <nav aria-label="Navigation principale">
            <ul>
              {sections.map((section) => {
                const Icon = SECTION_ICONS[section];
                return (
                  <li key={section}>
                    <NavLink to={SECTION_PATHS[section]}>
                      <Icon size={20} aria-hidden="true" />
                      {SECTION_LABELS[section]}
                      {section === 'alerts' && alertCount > 0 && (
                        <span className="nav-badge" aria-label={`${alertCount} alertes ouvertes`}>
                          {alertCount}
                        </span>
                      )}
                    </NavLink>
                  </li>
                );
              })}
            </ul>
          </nav>
        )}
        {user && (
          <div className="sidebar-user">
            <span className="avatar on-dark" aria-hidden="true">
              {initials(user.login)}
            </span>
            <span className="who">
              <strong>{user.login}</strong>
              <span>{ROLE_LABELS[user.role]}</span>
            </span>
            <button type="button" onClick={() => void logout()} title="Se déconnecter" aria-label="Se déconnecter">
              <LogOut size={18} />
            </button>
          </div>
        )}
      </aside>
      <div className="content">
        <header className="topbar">
          <button type="button" className="icon-btn menu-btn" onClick={() => setOpen(true)} aria-label="Ouvrir le menu">
            <Menu size={20} />
          </button>
          <span className="page-tag">{current ? SECTION_LABELS[current] : 'FANILO'}</span>
          <span className="spacer" />
          <Link to="/aide" className="icon-btn" aria-label="Aide : qui fait quoi ?" title="Aide : qui fait quoi ?">
            <CircleHelp size={20} />
          </Link>
          {alertsAllowed && (
            <Link to="/alertes" className="icon-btn" aria-label={`Alertes ouvertes : ${alertCount}`} title="Alertes ouvertes">
              <Bell size={20} />
              {alertCount > 0 && <span className="dot">{alertCount > 99 ? '99+' : alertCount}</span>}
            </Link>
          )}
          {user && (
            <span className="avatar" title={`${user.login} · ${ROLE_LABELS[user.role]}`}>
              {initials(user.login)}
            </span>
          )}
        </header>
        {isMock && (
          <div className="mock-banner" role="note">
            Mode démonstration : données fictives, aucun backend contacté.
          </div>
        )}
        <main id="contenu" className="app-main" tabIndex={-1}>
          <Outlet />
        </main>
        <Footer />
      </div>
    </div>
  );
}
