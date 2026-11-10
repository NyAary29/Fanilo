import { describe, expect, it } from 'vitest';
import type { Me, Role } from '../api/types';
import { ROLES } from '../api/types';
import { canSeeNominativeData, canValidateContent, canRetireContent, sectionsFor } from './permissions';

const me = (role: Role, id = 'moi'): Me => ({ id, login: 'x', role, site_id: null, is_active: true });

describe('permissions (ergonomiques)', () => {
  it('admin, data_officer et technical ne voient jamais de données nominatives', () => {
    expect(canSeeNominativeData(me('admin'))).toBe(false);
    expect(canSeeNominativeData(me('data_officer'))).toBe(false);
    expect(canSeeNominativeData(me('technical'))).toBe(false);
    expect(canSeeNominativeData(me('csb_head'))).toBe(true);
  });

  it('navigation par rôle', () => {
    expect(sectionsFor(me('admin'))).toEqual(['dashboard', 'stats', 'contents', 'users', 'sites']);
    expect(sectionsFor(me('data_officer'))).toEqual(['dashboard', 'stats', 'audit']);
    expect(sectionsFor(me('clinical_advisor'))).toEqual(['interactions', 'orientations', 'patients', 'alerts', 'referrals', 'simulator'])
    expect(sectionsFor(me('community_agent'))).toEqual(['patients', 'simulator']);
    expect(sectionsFor(me('technical'))).toEqual([]);
    for (const role of ROLES) {
      expect(sectionsFor(me(role)).includes('audit')).toBe(role === 'data_officer');
    }
  });

  it('valider : clinical_lead seulement, jamais son propre contenu', () => {
    const item = { status: 'in_review' as const, author_id: 'autre' };
    expect(canValidateContent(me('clinical_lead'), item)).toBe(true);
    expect(canValidateContent(me('clinical_lead', 'autre'), item)).toBe(false);
    expect(canValidateContent(me('admin'), item)).toBe(false);
    expect(canValidateContent(me('clinical_lead'), { ...item, status: 'draft' })).toBe(false);
  });

  it('retirer : clinical_lead seulement', () => {
    expect(canRetireContent(me('clinical_lead'), { status: 'validated' })).toBe(true);
    expect(canRetireContent(me('admin'), { status: 'validated' })).toBe(false);
  });
});
