/// Conduite à tenir en cas d'urgence.
///
/// La consigne générique (« allez au centre de santé le plus proche, sans
/// attendre ») est affichée partout. La procédure LOCALE réelle (numéro,
/// transport, personne à prévenir) doit être arrêtée par le responsable
/// clinique et le comité de pilotage : tant que ce n'est pas fait, cette
/// constante reste un texte « [À VALIDER] » affiché tel quel.
///
/// FANILO ne peut appeler personne : l'application est anonyme, aucune
/// alerte n'est créée et aucune prise en charge n'est promise.
const kLocalEmergencyProcedure =
    '[À VALIDER] Procédure locale d\'urgence (numéro, transport, personne à '
    'prévenir) à définir par le responsable clinique et le comité de pilotage.';
