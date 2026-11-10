import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { renderApp } from '../test/utils';

describe('garde de rôle et navigation', () => {
  it("redirige vers la connexion sans session, avec le pied de page permanent", async () => {
    await renderApp('/alertes');
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument();
    expect(screen.getByText('FANILO ne remplace pas un professionnel de santé.')).toBeInTheDocument();
  });

  it('connexion puis redirection vers le premier écran autorisé', async () => {
    const user = userEvent.setup();
    await renderApp('/connexion');
    await user.type(await screen.findByLabelText('Identifiant'), 'donnees');
    await user.type(screen.getByLabelText('Mot de passe'), 'demo');
    await user.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(await screen.findByRole('heading', { name: 'Tableau de bord' })).toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: 'Navigation principale' });
    expect(within(nav).getAllByRole('link').map((l) => l.textContent)).toEqual(['Tableau de bord', 'Statistiques', "Journal d'audit"]);
  });

  it('refuse un écran non autorisé pour le rôle (admin → audit)', async () => {
    await renderApp('/audit', { login: 'admin' });
    expect(await screen.findByRole('heading', { name: 'Accès non autorisé' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: "Journal d'audit" })).not.toBeInTheDocument();
  });

  it('autorise un écran permis (data_officer → audit)', async () => {
    await renderApp('/audit', { login: 'donnees' });
    expect(await screen.findByRole('heading', { name: "Journal d'audit" })).toBeInTheDocument();
    expect(await screen.findByText('referral.transition')).toBeInTheDocument();
  });

  it("affiche un message d'erreur sur identifiants invalides", async () => {
    const user = userEvent.setup();
    await renderApp('/connexion');
    await user.type(await screen.findByLabelText('Identifiant'), 'admin');
    await user.type(screen.getByLabelText('Mot de passe'), 'faux');
    await user.click(screen.getByRole('button', { name: 'Se connecter' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('Identifiant ou mot de passe incorrect.');
  });

  it("renvoie à la connexion quand la session expire (rafraîchissement refusé)", async () => {
    const view = await renderApp('/tableau-de-bord', { login: 'chef.csb' });
    expect(await screen.findByText('Alertes ouvertes')).toBeInTheDocument();
    view.server.expireAccessTokens();
    window.sessionStorage.clear(); // plus de jeton de rafraîchissement
    view.tokenStore.clear();
    await userEvent.setup().click(within(screen.getByRole('navigation', { name: 'Navigation principale' })).getByRole('link', { name: /^Alertes/ }));
    expect(await screen.findByRole('heading', { name: 'Connexion' })).toBeInTheDocument();
    expect(screen.getByText(/session a expiré/)).toBeInTheDocument();
  });
});
