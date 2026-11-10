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

describe('Simulateur vocal', () => {
  it('pose une question écrite et affiche la réponse, sans promesse de prise en charge', async () => {
    const user = userEvent.setup();
    await renderApp('/simulateur', { login: 'agent' });
    expect(await screen.findByRole('heading', { name: 'Assistant vocal' })).toBeInTheDocument();
    await user.click(screen.getByRole('tab', { name: 'Question écrite' }));
    await user.type(screen.getByLabelText(/Question \(malgache ou français\)/), 'fanontaniana');
    await user.click(screen.getByRole('button', { name: 'Envoyer la question' }));
    expect(await screen.findByText('Transfert à un conseiller humain')).toBeInTheDocument();
    expect(screen.getByText('Transférer à un conseiller')).toBeInTheDocument();
    expect(screen.getByText('FANILO ne remplace pas un professionnel de santé.', { selector: 'strong' })).toBeInTheDocument();
  });

  it("signale un signe de danger : l'alerte reste en attente d'accusé de réception", async () => {
    const user = userEvent.setup();
    await renderApp('/simulateur', { login: 'agent' });
    await user.click(await screen.findByRole('tab', { name: 'Signes (AC)' }));
    await user.click(await screen.findByRole('checkbox', { name: /Signe fictif n° 1/ }));
    await user.click(screen.getByRole('button', { name: 'Signaler' }));
    expect(await screen.findByText(/en attente d'accusé de réception/)).toBeInTheDocument();
  });

  it('affiche le menu à touches et le contenu choisi', async () => {
    const user = userEvent.setup();
    await renderApp('/simulateur', { login: 'agent' });
    await user.click(await screen.findByRole('button', { name: /Consultations prénatales/ }));
    expect(await screen.findByText(/Touche 1/)).toBeInTheDocument();
  });
});

describe('Statistiques', () => {
  it("affiche les cellules agrégées ; l'export DHIS2 est réservé au responsable données", async () => {
    await renderApp('/statistiques', { login: 'admin' });
    expect(await screen.findByText('MSG_DEMO_INFO_ANC')).toBeInTheDocument();
    expect(screen.queryByText('Export agrégé (format DHIS2)')).not.toBeInTheDocument();
  });

  it('le responsable données voit l’export', async () => {
    await renderApp('/statistiques', { login: 'donnees' });
    expect(await screen.findByText('Export agrégé (format DHIS2)')).toBeInTheDocument();
  });
});

describe('Espace agent et tableau de bord', () => {
  it('liste les patientes, les « à suivre » en tête, et ouvre le détail', async () => {
    const user = userEvent.setup();
    await renderApp('/patientes', { login: 'chef.csb' });
    expect(await screen.findByRole('heading', { name: 'Mes patientes' })).toBeInTheDocument();
    expect(await screen.findByText('Prochain rappel')).toBeInTheDocument();
    expect(screen.getAllByText('À suivre', { selector: '.badge' }).length).toBeGreaterThan(0);
    await user.click(screen.getByRole('radio', { name: /À suivre/ }));
    expect(screen.queryAllByText('À jour', { selector: '.badge' })).toHaveLength(0);
  });

  it('affiche le graphique d’activité avec sa vue tableau', async () => {
    const user = userEvent.setup();
    await renderApp('/tableau-de-bord', { login: 'admin' });
    expect(await screen.findByRole('heading', { name: 'Activité sur 6 mois' })).toBeInTheDocument();
    await user.click(await screen.findByRole('button', { name: 'Voir les données' }));
    expect(screen.getByRole('table')).toBeInTheDocument();
    expect(screen.getByText('Par centre de santé')).toBeInTheDocument();
  });
});

describe('Aide et orientation depuis une alerte', () => {
  it("explique le rôle de l'utilisateur", async () => {
    await renderApp('/aide', { login: 'chef.csb' });
    expect(await screen.findByRole('heading', { name: 'Votre rôle' })).toBeInTheDocument();
    expect(screen.getByText(/montre son code/)).toBeInTheDocument();
  });

  it('crée une référence depuis une alerte', async () => {
    const user = userEvent.setup();
    await renderApp(`/alertes/${ALERT_DEMO}`, { login: 'chef.csb' });
    const select = await screen.findByLabelText('Vers');
    const option = (await within(select).findByRole('option', { name: /Centre de référence fictif/ })) as HTMLOptionElement;
    await user.selectOptions(select, option.value);
    await user.click(screen.getByRole('button', { name: 'Créer la référence' }));
    expect(await screen.findByRole('heading', { name: 'Référence créée' })).toBeInTheDocument();
  });
});

describe('Suivi des orientations', () => {
  it('le responsable du centre retrouve la personne par son code', async () => {
    const user = userEvent.setup();
    await renderApp('/suivi', { login: 'chef.csb' });
    expect(await screen.findByText('K7-42')).toBeInTheDocument();
    await user.type(screen.getByLabelText('Code montré par la personne'), 'ZZ-99');
    expect(await screen.findByText(/Aucune personne avec le code ZZ-99/)).toBeInTheDocument();
  });
});
