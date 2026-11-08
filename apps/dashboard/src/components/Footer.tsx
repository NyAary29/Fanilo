export const DISCLAIMER = 'FANILO ne remplace pas un professionnel de santé.';

/** Pied de page permanent, présent sur tous les écrans (y compris la connexion). */
export function Footer() {
  return (
    <footer className="app-footer" role="contentinfo">
      <p>{DISCLAIMER}</p>
    </footer>
  );
}
