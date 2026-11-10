/** Emblème FANILO (dessin original) : visage de profil entouré de feuilles. */
export function LogoMark({ size = 48, light = false }: { size?: number; light?: boolean }) {
  const leaf = light ? '#f5b8d3' : '#d0568f';
  const leafDark = light ? '#e889b4' : '#9a2a5d';
  const face = light ? '#f6e3c8' : '#b8743a';
  return (
    <svg width={size} height={size} viewBox="0 0 64 64" aria-hidden="true" focusable="false">
      <circle cx="32" cy="32" r="30" fill={light ? 'rgb(255 255 255 / 10%)' : '#fbe6ef'} />
      {/* feuilles */}
      <path d="M10 40c2-10 9-15 18-15-2 9-8 15-18 15z" fill={leaf} />
      <path d="M8 30c4-8 11-11 18-9-4 7-10 10-18 9z" fill={leafDark} />
      <path d="M14 50c4-7 10-9 16-8-3 6-9 9-16 8z" fill={leafDark} />
      {/* visage de profil */}
      <path
        d="M40 12c-7 0-12 5-12 12 0 3 1 5 2 7l-3 5 4 1c0 3 1 5 4 5l1 6c4 1 9-1 11-4 3-4 4-9 4-15 0-10-4-17-11-17z"
        fill={face}
      />
      <path d="M41 11c-8-1-14 4-14 11 5-1 9-4 11-8 2 5 7 8 13 8-1-6-4-10-10-11z" fill={leafDark} />
    </svg>
  );
}

export function Brand({ light = false, tagline = true }: { light?: boolean; tagline?: boolean }) {
  return (
    <>
      <LogoMark size={56} light={light} />
      <span className="brand-name">FANILO</span>
      {tagline && <span className="brand-tag">Fahasalamana ho an&apos;ny rehetra</span>}
    </>
  );
}
