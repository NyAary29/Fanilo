import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useApi } from '../api/ApiProvider';
import { useAuth } from '../auth/AuthContext';
import { canSeeNominativeData } from '../auth/permissions';
import { shortId } from '../domain/format';
import { errorMessage } from './QueryState';

/**
 * Référence à un bénéficiaire : affiche le CODE PSEUDONYME (FAN-…).
 *
 * L'identité (nom, téléphone, village) n'est jamais chargée automatiquement : un rôle
 * nominatif peut la demander explicitement (lecture auditée côté serveur). Les rôles
 * admin, data_officer et technical ne voient jamais le bouton.
 */
export function BeneficiaryRef({ beneficiaryId, allowIdentity = false }: { beneficiaryId: string; allowIdentity?: boolean }) {
  const api = useApi();
  const { user } = useAuth();
  const [showIdentity, setShowIdentity] = useState(false);
  const nominative = canSeeNominativeData(user);

  const beneficiary = useQuery({
    queryKey: ['beneficiary', beneficiaryId],
    queryFn: () => api.getBeneficiary(beneficiaryId),
    staleTime: 5 * 60_000,
    retry: false,
  });
  const identity = useQuery({
    queryKey: ['beneficiary-identity', beneficiaryId],
    queryFn: () => api.getBeneficiaryIdentity(beneficiaryId),
    enabled: nominative && allowIdentity && showIdentity,
    staleTime: 0,
    gcTime: 0, // ne pas garder de données nominatives en cache
    retry: false,
  });

  const code = beneficiary.data?.code ?? `Bénéficiaire …${shortId(beneficiaryId)}`;

  return (
    <span className="beneficiary-ref">
      <span className="mono">{code}</span>
      {nominative && allowIdentity && !showIdentity && (
        <button type="button" className="btn btn-link" onClick={() => setShowIdentity(true)}>
          Afficher l&apos;identité (lecture tracée)
        </button>
      )}
      {nominative && allowIdentity && showIdentity && (
        <span className="identity" aria-live="polite">
          {identity.isPending && ' — chargement…'}
          {identity.error && <span className="error"> — {errorMessage(identity.error)}</span>}
          {identity.data && (
            <>
              {' — '}
              {identity.data.display_name}
              {identity.data.village && `, ${identity.data.village}`}
              {identity.data.phone && `, ${identity.data.phone}`}{' '}
              <button type="button" className="btn btn-link" onClick={() => setShowIdentity(false)}>
                Masquer
              </button>
            </>
          )}
        </span>
      )}
    </span>
  );
}
