# Déroulé de la démonstration FANILO

## Avant de monter sur scène (10 minutes)

Terminal 1, démarrer le serveur :

```bash
cd ~/Bureau/Fanilo
scripts/dev.sh start
```

Facultatif : le tableau de bord a l'air vide sans historique. Pour montrer des courbes et
des chiffres, ajoute 30 patientes **fictives** sur 6 mois (à effacer après la démo avec
`devseed --purge`) :

```bash
cd ~/Bureau/Fanilo/services/api && set -a && . ../../.env && set +a
~/.local/bin/uv run python -m app.modules.devseed --history
```

Brancher le téléphone en USB, déverrouillé, puis :

```bash
cd ~/Bureau/Fanilo
scripts/phone.sh
```

Le script installe l'app agent et l'app femmes, et relie le téléphone au serveur du PC.
Si la liaison saute (câble débranché) : `scripts/phone.sh link`.

Ouvrir **http://localhost:5174** sur le PC (projeté à l'écran).

## Démonstration (8 à 10 minutes)

### 1. La femme ou l'adolescente pose sa question (app femmes, téléphone)

1. Accueil « Salama ! » : **pas de compte**, anonyme.
2. Choisir **TANORA**, appuyer sur le micro, poser une question en malgache.
3. « Est-ce bien ce que vous avez dit ? » : FANILO montre ce qu'il a compris. Si c'est faux,
   **Non, je l'écris** permet de corriger.
4. Réponse : message validé, ou « transmise à un conseiller ».

Message clé : *l'IA comprend la voix, mais ne décide jamais seule ; les réponses viennent
de contenus validés par des professionnels de santé.*

### 2. Le conseiller répond (dashboard, rôle « Conseiller »)

1. Bouton **Conseiller** sur l'écran de connexion.
2. **Questions à revoir** : la question anonyme apparaît avec ce qui a été compris.
3. Écrire la réponse, **Enregistrer la revue**.
4. Sur le téléphone : « **Vous avez une réponse** » apparaît en moins de 15 secondes.

### 3. Signe de danger (app femmes)

Dire ou écrire « mandeha ra aho » (« je saigne ») dans RENY : grand bloc rouge
**« Allez au centre de santé le plus proche, sans attendre »**.

Message clé : *même en cas de doute de l'IA, la prudence l'emporte.*

### 4. L'agent communautaire sur le terrain (app agent, téléphone)

1. Connexion `ac.a1` / `fanilo-demo-2026`.
2. **Nouvelle patiente** : consentement d'abord, puis le nom.
3. **Déclarer une grossesse** avec la date des dernières règles, puis **Synchroniser** :
   le calendrier des CPN arrive.
4. **Alerter** : cocher un signe, puis **Envoyer**.
5. Montrer que tout fonctionne **hors connexion** : mode avion, saisie, puis
   synchronisation au retour du réseau.

### 5. Le CSB reçoit l'alerte (dashboard, rôle « Chef CSB »)

1. La cloche affiche l'alerte. **Alertes**, ouvrir l'alerte, puis **Acquitter**.
2. **Tableau de bord** : indicateurs, activité sur 6 mois, par centre de santé.
3. **Mes patientes** : qui suivre en priorité.

### 6. Pilotage et données (dashboard, rôle « Responsable données »)

**Statistiques** : thèmes des questions (anonymisés), export DHIS2 ; **Journal d'audit**.

## Si quelque chose ne marche pas

| Problème | Solution |
|---|---|
| « Impossible de joindre le serveur » sur le téléphone | `scripts/phone.sh link` |
| Dashboard inaccessible | `scripts/dev.sh start` |
| La voix n'est pas comprise | Utiliser **Écrire la question** (même parcours ensuite) |
| Réponse du conseiller qui n'arrive pas | Onglet « Ny fanontaniako », puis le bouton actualiser |

## Ce qu'il faut dire honnêtement au jury

- Les messages de santé et la liste des signes de danger sont des **exemples de
  démonstration** : ils doivent être validés par le responsable clinique.
- La reconnaissance vocale du malgache est un **modèle open source** pas encore évalué sur
  de vraies voix du terrain : c'est l'objet de la phase d'évaluation prévue (M7-M8).
- Canaux téléphoniques réels (appels, SMS) : prévus avec un opérateur partenaire.
