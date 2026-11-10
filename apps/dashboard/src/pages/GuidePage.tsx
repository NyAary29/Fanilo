import { Link } from 'react-router-dom';
import type { Role } from '../api/types';
import { useCurrentUser } from '../auth/AuthContext';
import { ROLE_LABELS } from '../auth/permissions';

interface RoleGuide {
  mission: string;
  steps: { text: string; to?: string; link?: string }[];
}

const GUIDES: Partial<Record<Role, RoleGuide>> = {
  community_agent: {
    mission: "Vous suivez les femmes enceintes de votre village avec l'application mobile (elle marche sans réseau).",
    steps: [
      { text: 'Enregistrer une femme : « Nouvelle patiente », consentement d’abord, puis son nom.' },
      { text: 'Déclarer sa grossesse avec la date des dernières règles, puis « Synchroniser » : le calendrier des CPN arrive.' },
      { text: 'À chaque visite : « Visite du jour » (signes de danger ? conseils, prochain rendez-vous).' },
      { text: 'Signe de danger : onglet « Alerter », cocher les signes. Le chef du CSB reçoit une alerte.' },
      { text: 'Voir qui suivre en priorité ici aussi :', to: '/patientes', link: 'Mes patientes' },
    ],
  },
  csb_head: {
    mission:
      'Vous êtes le responsable du suivi : les femmes que le conseiller envoie vers votre centre y sont attendues, et vous enregistrez leur venue.',
    steps: [
      { text: 'Voir les femmes attendues dans votre centre :', to: '/suivi', link: 'Suivi des orientations' },
      { text: 'Quand une femme se présente, elle montre son code (ex. K7-42) : tapez-le dans la recherche.' },
      { text: 'Cliquez « Elle est venue » (ou « Pas venue »). Le conseiller et la femme le voient.' },
      { text: 'Les urgentes (🔴) sont en haut : à recevoir en priorité.' },
      { text: 'Les alertes envoyées par les agents de village :', to: '/alertes', link: 'Alertes' },
    ],
  },
  clinical_advisor: {
    mission: 'Vous répondez aux femmes et aux adolescentes, vous classez leur situation et vous les orientez vers un centre de santé.',
    steps: [
      { text: 'Ouvrez la liste (les urgences sont en haut) :', to: '/questions', link: 'Questions des femmes' },
      { text: '1. Classez : 🔴 Urgent, 🟠 À suivre ou 🟢 Simple information.' },
      { text: '2. Écrivez ce qu’elle doit faire (ou cliquez une réponse toute prête).' },
      {
        text: '3. Choisissez le centre de santé. Pour 🔴 et 🟠, c’est obligatoire : la femme reçoit un code, et le centre fait le suivi.',
      },
      { text: '« Envoyer la réponse » : elle la lit dans son application en moins de 15 secondes.' },
      { text: 'Voir si elles sont venues au centre :', to: '/suivi', link: 'Suivi des orientations' },
    ],
  },
  clinical_lead: {
    mission: 'Vous garantissez que FANILO ne diffuse que des messages de santé validés.',
    steps: [
      { text: 'Rédiger ou corriger un message :', to: '/contenus', link: 'Contenus' },
      { text: '« Soumettre à validation », puis un AUTRE responsable clinique le « Valide » (jamais l’auteur lui-même).' },
      { text: 'Retirer un message dépassé : « Retirer ».' },
      { text: 'Vous voyez aussi toutes les alertes, références et questions, toutes zones confondues.' },
    ],
  },
  admin: {
    mission: 'Vous créez les comptes et les centres de santé. Vous ne voyez jamais le nom des patientes.',
    steps: [
      { text: 'Créer un CSB, puis ses zones communautaires (rattachées au CSB) :', to: '/sites', link: 'Sites' },
      { text: 'Créer un compte par personne (rôle + site), mot de passe de 12 caractères ou plus :', to: '/utilisateurs', link: 'Utilisateurs' },
      { text: 'Désactiver un compte quand une personne quitte le projet.' },
    ],
  },
  data_officer: {
    mission: 'Vous veillez à la protection des données et vous produisez les indicateurs.',
    steps: [
      { text: 'Qui a fait quoi (connexions, lectures de noms, exports) :', to: '/audit', link: 'Journal d’audit' },
      { text: 'Thèmes des questions et export DHIS2 mensuel :', to: '/statistiques', link: 'Statistiques' },
    ],
  },
};

const FLOW = [
  {
    who: '① Femme / adolescente',
    where: 'App « Femmes », sans compte',
    what: 'Écrit son problème ou son urgence.',
  },
  {
    who: '② Conseiller',
    where: 'Dashboard → Questions des femmes',
    what: 'Classe (urgent, à suivre, information), répond, et l’oriente vers un centre de santé.',
  },
  {
    who: '③ Responsable du centre (chef CSB)',
    where: 'Dashboard → Suivi des orientations',
    what: 'Reconnaît la femme à son code, enregistre « venue » ou « pas venue ».',
  },
  {
    who: '④ Femme / adolescente',
    where: 'App « Femmes » → Mes questions',
    what: 'Voit la réponse, le centre où aller et son code à montrer.',
  },
];


export function GuidePage() {
  const user = useCurrentUser();
  const guide = GUIDES[user.role];
  return (
    <section aria-labelledby="guide-title" className="stack">
      <div>
        <h1 id="guide-title">Aide : qui fait quoi ?</h1>
        <p className="subtitle">Vous êtes connecté(e) en tant que « {ROLE_LABELS[user.role]} ».</p>
      </div>

      {guide && (
        <div className="panel stack-sm">
          <h2>Votre rôle</h2>
          <p>
            <strong>{guide.mission}</strong>
          </p>
          <ol className="steps">
            {guide.steps.map((s) => (
              <li key={s.text}>
                <span>
                  {s.text} {s.to && <Link to={s.to}>{s.link}</Link>}
                </span>
              </li>
            ))}
          </ol>
        </div>
      )}

      <div className="panel stack-sm">
        <h2>Le parcours FANILO</h2>
        <div className="table-wrap">
          <table className="table">
            <thead>
              <tr>
                <th scope="col">Qui</th>
                <th scope="col">Où</th>
                <th scope="col">Ce qu’il fait</th>
              </tr>
            </thead>
            <tbody>
              {FLOW.map((f) => (
                <tr key={f.who}>
                  <td data-label="Qui">
                    <strong>{f.who}</strong>
                  </td>
                  <td data-label="Où">{f.where}</td>
                  <td data-label="Ce qu’il fait">{f.what}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="muted small">
          En complément (facultatif) : les <strong>agents communautaires</strong> des villages suivent les femmes enceintes
          avec l’application Agent (grossesse, consultations prénatales) et envoient des <strong>alertes</strong> au chef du
          CSB, qui peut orienter la patiente avec une <strong>référence</strong>.
        </p>
      </div>
    </section>
  );
}
