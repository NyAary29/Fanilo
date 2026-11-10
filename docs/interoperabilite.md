# Interopérabilité (F-17, P1)

> Statut : **interface préparatoire**. Aucune donnée n'est transmise à CommCare, DHIS2 ou
> à un autre système. Toute intégration en production exige une validation technique,
> institutionnelle et contractuelle (cahier des charges §4.2).

## Ce qui existe

| Interface | Usage | Accès |
|---|---|---|
| API REST documentée (OpenAPI : `/openapi.json`, `/docs` hors production) | Toute intégration future passe par l'API, jamais par la base | Comptes et rôles FANILO |
| `GET /interop/dhis2/data-value-set?period=AAAAMM` | Export agrégé mensuel au format DHIS2 `dataValueSet` (JSON) | `data_officer` uniquement, chaque export est audité (`export.aggregates`) |
| Écran « Statistiques » du dashboard | Téléchargement du même export par le responsable données | Idem |

## Export DHIS2 : règles

- **Agrégats uniquement**, par CSB : `orgUnit` = code du site FANILO. Une zone
  communautaire est comptée dans son CSB parent ; une donnée sans CSB de rattachement
  n'est pas exportée.
- Aucun identifiant de bénéficiaire, aucun nom, aucun contenu de question.
- **Secret statistique** : les valeurs inférieures à `FANILO_STATS_MIN_CELL_SIZE` (5 par
  défaut) sont retirées, sauf `include_small_cells=true` (choix explicite, audité comme
  tout export). Le nombre de valeurs retirées est indiqué (`suppressed_values`).
- Période : mois civil UTC.

### Éléments de données

| Code FANILO | Définition | Indicateur du cahier des charges |
|---|---|---|
| `FANILO_PREG_NEW` | Grossesses enregistrées dans le mois | Suivi RENY |
| `FANILO_ANC_DONE` | CPN réalisées (date de réalisation dans le mois) | Suivi CPN |
| `FANILO_ANC1_BEFORE_16W` | CPN1 réalisées au plus tard à 16 semaines après la DDR (DDR connue) | « CPN avant 16 semaines » |
| `FANILO_ANC_MISSED` | CPN marquées manquées (date prévue dans le mois) | Suivi CPN |
| `FANILO_ALERTS` | Alertes de signe de danger créées | F-08 |
| `FANILO_ALERTS_ACK_IN_TIME` | Alertes acquittées avant leur échéance | « Alerte non traitée » (risques) |
| `FANILO_REFERRALS` | Références créées | F-09 |
| `FANILO_REFERRALS_ARRIVED` | Références au statut « arrivée au CSB » | « Références suivies » |
| `FANILO_QUESTIONS` | Questions posées (toutes formes) | Usage |
| `FANILO_QUESTIONS_TRANSFERRED` | Questions transférées au conseiller (fallback) | Qualité des réponses |

## À valider avant toute intégration

1. Correspondance entre ces codes et les **UID** des éléments de données et des unités
   d'organisation du DHIS2 national (table de correspondance à maintenir hors code).
2. Définitions des indicateurs avec l'équipe suivi-évaluation (ex. définition de la DDR
   « connue », traitement des grossesses transférées).
3. Autorisation institutionnelle (Ministère, DRSP/SDSP) et accord sur le mode de
   transmission : import manuel du fichier, ou adaptateur qui pousse vers
   `/api/dataValueSets` avec un compte technique dédié.
4. Pour CommCare : périmètre (cas individuels ou agrégats), base légale du partage de
   données individuelles et pseudonymisation ; rien n'est prévu tant que ce cadre
   n'existe pas.
