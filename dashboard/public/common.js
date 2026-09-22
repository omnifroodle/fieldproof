// Shared helpers for the two pages.

export const STATUS_LABEL = { open: 'Open', in_progress: 'In progress', resolved: 'Resolved' };
export const CATEGORY_LABEL = { pothole: 'Pothole', graffiti: 'Graffiti', tree: 'Downed tree', fixture: 'Broken fixture', other: 'Other' };
const STATUS_COLOR = { open: '#C4552D', in_progress: '#D9A441', resolved: '#1F3D2B' };

export const thumbUrl = (r) => `/api/thumbnail/${encodeURIComponent(r.id)}?d=${encodeURIComponent(r.thumb ?? '')}`;

export const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function ago(iso) {
  const s = (Date.now() - Date.parse(iso)) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.floor(s / 60)} min ago`;
  if (s < 86400) return `${Math.floor(s / 3600)} h ago`;
  return `${Math.floor(s / 86400)} d ago`;
}

/** 28×36 teardrop pin in the status color with a charcoal outline and a white dot. */
export function pinIcon(status, isNew) {
  const svg = `<svg width="28" height="36" viewBox="0 0 28 36"><path d="M14 35C14 35 2 21 2 13a12 12 0 0 1 24 0c0 8-12 22-12 22z"
    fill="${STATUS_COLOR[status] ?? '#7A9EAB'}" stroke="#2B2B2B" stroke-width="2"/><circle cx="14" cy="13" r="4.5" fill="#FBF7EE"/></svg>`;
  return L.divIcon({ html: svg, className: `pin${isNew ? ' new' : ''}`, iconSize: [28, 36], iconAnchor: [14, 35], popupAnchor: [0, -30] });
}
