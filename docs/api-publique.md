# API publique anonyme (application « FANILO Femmes & Adolescentes »)

Aucun compte, aucun jeton d'authentification, aucun nom, aucun numéro de téléphone.
Préfixe `/public`. Réponses JSON, `snake_case`. Limitation de débit par adresse IP :
**429** au-delà de `FANILO_PUBLIC_ASK_PER_HOUR` questions par heure (30 par défaut).

> FANILO ne remplace pas un professionnel de santé. Une utilisatrice anonyme ne peut pas
> être rappelée : aucune alerte nominative n'est créée, et l'application affiche toujours
> la conduite à tenir en cas d'urgence.

## Référentiels

| Méthode | Chemin | Réponse |
|---|---|---|
| GET | `/public/sites` | `{items: [{id, name, district, region}]}` : CSB actifs (facultatif : « Où habitez-vous ? », sert seulement à orienter la question vers les conseillers de la zone) |
| GET | `/public/information` (fichier `public_information*.yaml`, textes propres à l'usage anonyme) | `{items: [{scope, version, status, summary_fr, summary_mg\|null}]}` : information à présenter (portées `tanora`, `reny`, `voice_processing`) |
| GET | `/public/menus?module=reny\|tanora&language=mg\|fr` | identique à `/reference/menus` : `{config_id, version, is_demo, module, items: [{key, code, title, body, audio_url, status}]}` |

Les référentiels répondent **503** s'ils ne sont pas servis (statut non validé hors mode démo).

## Poser une question

`POST /public/ask`, deux formes :

- JSON `{module: "reny"|"tanora", text, language?: "mg"|"fr", site_id?}` ;
- `multipart/form-data` : `audio` (fichier), `module`, `language?`, `site_id?`, **`voice_consent=true`** obligatoire (sinon 422 `consent_required`). L'en-tête `Content-Length` est obligatoire (411 sinon, 413 au-delà de la taille maximale). L'audio est transcrit en mémoire et **jamais conservé**.

Réponse :

```json
{
  "question_id": "uuid",
  "transcript": "texte|null",
  "transcript_needs_review": false,
  "outcome": "answer|danger_sign|fallback",
  "actions": ["refer_csb"],
  "content": null | {"code": "MSG_...", "title": "...", "body": "...", "audio_url": null, "status": "validated|demo"},
  "urgent": true,
  "follow_up": null | {"token": "secret", "status": "pending"},
  "is_demo": true,
  "disclaimer": "FANILO ne remplace pas un professionnel de santé."
}
```

- `urgent = true` quand un signe de danger est reconnu par les règles **ou seulement soupçonné** (codes proposés par l'IA, même sous le seuil de confiance ; par prudence, car l'utilisatrice ne peut pas être rappelée) : l'application affiche en grand
  « Allez au centre de santé le plus proche, sans attendre » et le contenu d'orientation.
  **Aucune alerte n'est créée** (personne n'est joignable), aucune promesse de prise en charge.
- `follow_up` est présent quand la question part en revue chez un conseiller (fallback,
  TANORA, signe de danger). Le `token` n'est renvoyé **qu'une fois** : l'application le
  garde sur le téléphone. Le serveur n'en stocke qu'une empreinte.

## Récupérer la réponse du conseiller

`GET /public/questions/{question_id}?token=…` →
`{question_id, module, status: "pending"|"answered", answer|null, answered_at|null, orientation: null|{name, kind, district, region}, triage: null|"urgent"|"follow_up"|"info", follow_up_code: null|"K7-42", follow_up_status: null|"expected"|"came"|"no_show"}`. Quand le conseiller classe la situation « urgent » ou « à suivre », il choisit un centre et un **code** est créé : l'utilisatrice le montre au centre, qui enregistre sa venue (`came`) ou son absence (`no_show`).
404 si l'identifiant ou le jeton est faux (on ne révèle pas l'existence).

`DELETE /public/questions/{question_id}?token=…` → 204 : l'utilisatrice efface sa question
(transcription et réponse supprimées du serveur).
