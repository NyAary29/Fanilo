import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { createBrowserRouter, createMemoryRouter, Navigate, RouterProvider, type RouteObject } from 'react-router-dom';
import { ApiError } from './api/client';
import { ApiProvider, type ApiContextValue } from './api/ApiProvider';
import { AuthProvider } from './auth/AuthContext';
import { SECTION_ROLES } from './auth/permissions';
import { RequireRole } from './auth/RequireRole';
import { Layout } from './components/Layout';
import { AlertDetailPage } from './pages/AlertDetailPage';
import { AlertsPage } from './pages/AlertsPage';
import { AuditPage } from './pages/AuditPage';
import { ContentsPage } from './pages/ContentsPage';
import { DashboardPage } from './pages/DashboardPage';
import { HomePage, NotFoundPage } from './pages/HomePage';
import { InteractionsPage } from './pages/InteractionsPage';
import { LoginPage } from './pages/LoginPage';
import { ReferralDetailPage } from './pages/ReferralDetailPage';
import { ReferralsPage } from './pages/ReferralsPage';
import { SitesPage } from './pages/SitesPage';
import { UsersPage } from './pages/UsersPage';

/**
 * Routes. Chaque écran est enveloppé par <RequireRole> selon SECTION_ROLES.
 * Rappel : garde ERGONOMIQUE ; l'API fait seule autorité (403 / 404).
 */
export const routes: RouteObject[] = [
  { path: '/connexion', element: <LoginPage /> },
  {
    element: (
      <RequireRole>
        <Layout />
      </RequireRole>
    ),
    children: [
      { index: true, element: <Navigate to="/accueil" replace /> },
      { path: '/accueil', element: <HomePage /> },
      { path: '/tableau-de-bord', element: <RequireRole roles={SECTION_ROLES.dashboard}><DashboardPage /></RequireRole> },
      { path: '/alertes', element: <RequireRole roles={SECTION_ROLES.alerts}><AlertsPage /></RequireRole> },
      { path: '/alertes/:id', element: <RequireRole roles={SECTION_ROLES.alerts}><AlertDetailPage /></RequireRole> },
      { path: '/references', element: <RequireRole roles={SECTION_ROLES.referrals}><ReferralsPage /></RequireRole> },
      { path: '/references/:id', element: <RequireRole roles={SECTION_ROLES.referrals}><ReferralDetailPage /></RequireRole> },
      { path: '/contenus', element: <RequireRole roles={SECTION_ROLES.contents}><ContentsPage /></RequireRole> },
      { path: '/utilisateurs', element: <RequireRole roles={SECTION_ROLES.users}><UsersPage /></RequireRole> },
      { path: '/sites', element: <RequireRole roles={SECTION_ROLES.sites}><SitesPage /></RequireRole> },
      { path: '/questions', element: <RequireRole roles={SECTION_ROLES.interactions}><InteractionsPage /></RequireRole> },
      { path: '/audit', element: <RequireRole roles={SECTION_ROLES.audit}><AuditPage /></RequireRole> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
];

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        // Ne pas réessayer les erreurs d'autorisation ou de validation.
        retry: (failureCount, error) =>
          !(error instanceof ApiError && error.status >= 400 && error.status < 500) && failureCount < 2,
        refetchOnWindowFocus: true,
      },
      mutations: { retry: false },
    },
  });
}

export function AppProviders({ api, queryClient, children }: { api: ApiContextValue; queryClient: QueryClient; children: ReactNode }) {
  return (
    <ApiProvider value={api}>
      <QueryClientProvider client={queryClient}>
        <AuthProvider>{children}</AuthProvider>
      </QueryClientProvider>
    </ApiProvider>
  );
}

export function App({ api, initialPath }: { api: ApiContextValue; initialPath?: string }) {
  const [queryClient] = useState(createQueryClient);
  const [router] = useState(() =>
    initialPath ? createMemoryRouter(routes, { initialEntries: [initialPath] }) : createBrowserRouter(routes),
  );
  return (
    <AppProviders api={api} queryClient={queryClient}>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
