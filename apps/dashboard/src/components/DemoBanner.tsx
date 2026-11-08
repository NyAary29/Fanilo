/** Bandeau affiché dès qu'un élément provient d'un jeu de règles ou d'un contenu de démonstration. */
export function DemoBanner({ isDemo }: { isDemo: boolean }) {
  if (!isDemo) return null;
  return (
    <div className="demo-banner" role="alert">
      <strong>DÉMO — non validé cliniquement.</strong> Cet élément provient de règles ou de contenus de
      démonstration : ne pas l&apos;utiliser pour une décision de soins.
    </div>
  );
}
