import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { renderApp } from '../test/utils';

const ALERT_DEMO = 'a1e00000-0000-4000-8000-000000000001';
const ALERT_VALIDATED = 'a1e00000-0000-4000-8000-000000000005';
const REFERRAL_ACCEPTED = '4ef00000-0000-4000-8000-000000000002';

describe('Alertes', () => {
  it('met en évidence les alertes en retard et filtre par statut', async () => {
    const user = userEvent.setup();
    await renderApp('/alertes', { login: 'chef.csb' });
    const table = await screen.findByRole('table');
    expect(within(table).getAllByText('En retard').length).toBeGreaterThan(0);
    expect(table.querySelector('.row-overdue')).not.toBeNull();

    await user.selectOptions(screen.getByLabelText('Statut'), 'resolved');
    await waitFor(() => expect(within(screen.getByRole('table')).queryByText('En retard')).not.toBeInTheDocument());
    expect(within(screen.getByRole('table')).getAllByRole('row')).toHaveLength(2); // en-tête + 1 alerte résolue
  });

  it('affiche le bandeau DÉMO et le journal sur une alerte de démonstration', async () => {
    await renderApp(`/alertes/${ALERT_DEMO}`, { login: 'chef.csb' });
    expect(await screen.findByText('DÉMO — non validé cliniquement.')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Journal des événements' })).toBeInTheDocument();
  });

  it("n'affiche pas le bandeau DÉMO sur une alerte issue de règles validées", async () => {
    await renderApp(`/alertes/${ALERT_VALIDATED}`, { login: 'chef.csb' });
    expect(await screen.findByRole('heading', { name: /Alerte/ })).toBeInTheDocument();
    expect(screen.queryByText('DÉMO — non validé cliniquement.')).not.toBeInTheDocument();
  });

  it('acquitte une alerte et journalise une note', async () => {
    const user = userEvent.setup();
    const { server } = await renderApp(`/alertes/${ALERT_DEMO}`, { login: 'chef.csb' });
    await user.click(await screen.findByRole('button', { name: 'Acquitter (accusé de réception)' }));
    await waitFor(() => expect(screen.queryByRole('button', { name: /Acquitter/ })).not.toBeInTheDocument());
    expect(server.db.alerts[0]?.status).toBe('acknowledged');

    await user.type(screen.getByLabelText('Ajouter une note au journal'), 'Appel passé');
    await user.click(screen.getByRole('button', { name: 'Ajouter la note' }));
    expect(await screen.findByText('Appel passé')).toBeInTheDocument();
  });
});

describe('Références', () => {
  it('applique une transition non aboutie avec motif', async () => {
    const user = userEvent.setup();
    const { server } = await renderApp(`/references/${REFERRAL_ACCEPTED}`, { login: 'chef.csb' });
    await user.click(await screen.findByRole('radio', { name: 'Non aboutie' }));
    await user.type(screen.getByLabelText('Motif (obligatoire)'), 'Famille injoignable');
    await user.click(screen.getByRole('button', { name: 'Enregistrer la transition' }));
    expect(await screen.findByText(/état final/)).toBeInTheDocument();
    expect(server.db.referrals[1]).toMatchObject({ status: 'not_completed', reason: 'Famille injoignable' });
  });
});

describe('Contenus', () => {
  it('masque « Valider » sur le contenu dont on est l’auteur et le montre sinon', async () => {
    await renderApp('/contenus?statut=in_review', { login: 'responsable' });
    expect(await screen.findByRole('button', { name: 'Valider MSG_DEMO_HYGIENE' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Valider MSG_DEMO_SOMMEIL' })).not.toBeInTheDocument();
  });

  it("n'affiche jamais « Valider » ni « Retirer » à l'administrateur", async () => {
    await renderApp('/contenus', { login: 'admin' });
    expect(await screen.findByText('MSG_DEMO_HYGIENE', { selector: '.mono' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Valider/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /^Retirer/ })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Soumettre à validation MSG_DEMO_ORIENTATION_CSB' })).toBeInTheDocument();
  });
});

describe('Données nominatives', () => {
  it("propose la lecture d'identité à un rôle nominatif uniquement", async () => {
    const user = userEvent.setup();
    await renderApp(`/alertes/${ALERT_DEMO}`, { login: 'chef.csb' });
    await user.click(await screen.findByRole('button', { name: /Afficher l'identité/ }));
    expect(await screen.findByText(/Personne fictive 1/)).toBeInTheDocument();
  });

  it("n'affiche aucun champ nominatif à l'administrateur (utilisateurs)", async () => {
    await renderApp('/utilisateurs', { login: 'admin' });
    expect(await screen.findByText('chef.csb', { selector: 'td' })).toBeInTheDocument();
    expect(screen.queryByText(/Personne fictive/)).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Afficher l'identité/ })).not.toBeInTheDocument();
  });
});
