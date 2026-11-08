export const PAGE_SIZE = 25;

export function Pagination({
  offset,
  total,
  limit = PAGE_SIZE,
  onChange,
}: {
  offset: number;
  total: number;
  limit?: number;
  onChange: (offset: number) => void;
}) {
  if (total <= limit) return null;
  const page = Math.floor(offset / limit) + 1;
  const pages = Math.max(1, Math.ceil(total / limit));
  return (
    <nav className="pagination" aria-label="Pagination">
      <button type="button" className="btn btn-secondary" disabled={offset === 0} onClick={() => onChange(Math.max(0, offset - limit))}>
        Précédent
      </button>
      <span aria-live="polite">
        Page {page} sur {pages} ({total} éléments)
      </span>
      <button type="button" className="btn btn-secondary" disabled={offset + limit >= total} onClick={() => onChange(offset + limit)}>
        Suivant
      </button>
    </nav>
  );
}
