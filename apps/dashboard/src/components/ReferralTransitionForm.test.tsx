import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { ReferralTransitionForm } from './ReferralTransitionForm';

describe('ReferralTransitionForm', () => {
  it("ne propose que les transitions autorisées depuis l'état courant", () => {
    render(<ReferralTransitionForm current="proposed" onSubmit={vi.fn()} />);
    const options = screen.getAllByRole('radio').map((r) => r.parentElement?.textContent);
    expect(options).toEqual(['Acceptée', 'Non aboutie']);
  });

  it('affiche un état final sans formulaire', () => {
    render(<ReferralTransitionForm current="arrived" onSubmit={vi.fn()} />);
    expect(screen.queryByRole('radio')).not.toBeInTheDocument();
    expect(screen.getByText(/état final/)).toBeInTheDocument();
  });

  it('bloque not_completed sans motif, puis envoie avec le motif', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<ReferralTransitionForm current="accepted" onSubmit={onSubmit} />);

    await user.click(screen.getByRole('radio', { name: 'Non aboutie' }));
    expect(screen.getByLabelText('Motif (obligatoire)')).toBeRequired();
    await user.click(screen.getByRole('button', { name: 'Enregistrer la transition' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Le motif est obligatoire');
    expect(screen.getByLabelText('Motif (obligatoire)')).toHaveAttribute('aria-invalid', 'true');
    expect(onSubmit).not.toHaveBeenCalled();

    await user.type(screen.getByLabelText('Motif (obligatoire)'), 'Transport indisponible');
    await user.click(screen.getByRole('button', { name: 'Enregistrer la transition' }));
    expect(onSubmit).toHaveBeenCalledWith({ to_status: 'not_completed', reason: 'Transport indisponible' });
  });

  it('le motif reste facultatif pour les autres transitions', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<ReferralTransitionForm current="accepted" onSubmit={onSubmit} />);
    await user.click(screen.getByRole('radio', { name: 'Arrivée' }));
    expect(screen.getByLabelText('Motif (facultatif)')).not.toBeRequired();
    await user.click(screen.getByRole('button', { name: 'Enregistrer la transition' }));
    expect(onSubmit).toHaveBeenCalledWith({ to_status: 'arrived' });
  });

  it('exige un choix de statut', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<ReferralTransitionForm current="proposed" onSubmit={onSubmit} />);
    await user.click(screen.getByRole('button', { name: 'Enregistrer la transition' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Choisissez le nouveau statut.');
    expect(onSubmit).not.toHaveBeenCalled();
  });
});
