import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { DemoBanner } from './DemoBanner';

describe('DemoBanner', () => {
  it('s’affiche quand is_demo vaut vrai', () => {
    render(<DemoBanner isDemo />);
    expect(screen.getByRole('alert')).toHaveTextContent('DÉMO — non validé cliniquement');
  });
  it('ne s’affiche pas sinon', () => {
    render(<DemoBanner isDemo={false} />);
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });
});
