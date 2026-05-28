const BADGE_COLOR_MAP = {
  Library: 'bg-n-teal-4 text-n-teal-11 ring-1 ring-inset ring-n-teal-7',
  Teacher: 'bg-n-blue-4 text-n-blue-11 ring-1 ring-inset ring-n-blue-7',
  Student: 'bg-n-amber-4 text-n-amber-11 ring-1 ring-inset ring-n-amber-7',
  Center: 'bg-n-purple-4 text-n-purple-11 ring-1 ring-inset ring-n-purple-7',
  Other: 'bg-n-slate-4 text-n-slate-11 ring-1 ring-inset ring-n-slate-7',
};

const CARD_ACTIVE_COLOR_MAP = {
  Library: 'border-n-teal-7 bg-n-teal-4 text-n-teal-11',
  Teacher: 'border-n-blue-7 bg-n-blue-4 text-n-blue-11',
  Student: 'border-n-amber-7 bg-n-amber-4 text-n-amber-11',
  Center: 'border-n-purple-7 bg-n-purple-4 text-n-purple-11',
  Other: 'border-n-slate-7 bg-n-slate-4 text-n-slate-11',
};

export const getClassificationBadgeClass = value =>
  BADGE_COLOR_MAP[value] ||
  'bg-n-alpha-2 text-n-slate-11 ring-1 ring-inset ring-n-weak';

export const getClassificationCardActiveClass = value =>
  CARD_ACTIVE_COLOR_MAP[value] ||
  'border-n-brand/40 bg-n-brand/10 text-n-blue-11';
