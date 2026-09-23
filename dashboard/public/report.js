// Report detail: photo, metadata, attached captures, hash verification, status buttons.
import { STATUS_LABEL, CATEGORY_LABEL, thumbUrl, ago, esc } from './common.js';

const id = new URLSearchParams(location.search).get('id');
const $ = (x) => document.getElementById(x);
const dl = (pairs) => pairs.map(([k, v]) => `<dt>${k}</dt><dd>${v}</dd>`).join('');

async function load() {
  const res = await fetch(`/api/reports/${encodeURIComponent(id)}`);
  if (!res.ok) { document.body.innerHTML = '<div class="empty">REPORT NOT FOUND</div>'; return; }
  const r = await res.json();

  $('title').textContent = (CATEGORY_LABEL[r.category] ?? r.category).toUpperCase();
  $('pill').className = `pill ${r.status}`;
  $('pill').textContent = STATUS_LABEL[r.status];
  $('photo').src = `/api/photo/${encodeURIComponent(id)}?t=${Date.now()}`;
  $('hash').textContent = r.imageHash;

  const loc = r.location ?? {};
  $('facts').innerHTML = dl([
    ['Taken', `${new Date(r.createdAt).toLocaleString()} (${ago(r.createdAt)})`],
    ['Where', `${loc.lat?.toFixed(5)}, ${loc.lon?.toFixed(5)} ±${Math.round(loc.accuracy ?? 0)} m`],
    ['Heading', `${Math.round(loc.heading ?? 0)}° · ${Math.round(loc.altitude ?? 0)} m elevation`],
    ['District', esc(r.district)],
    ['Filed by', esc(r.createdBy)],
    ...(r.summary ? [['Written on the device', esc(r.summary)]] : []),
    ['Notes', esc(r.notes) || '—'],
    ['ID', `<span class="mono">${esc(r.id)}</span>`],
    ...(r.attachedTo ? [['Attached to', `<a href="report.html?id=${encodeURIComponent(r.attachedTo)}">${esc(r.attachedTo)}</a>`]] : []),
  ]);
  $('ai').innerHTML = dl([
    ['Labels', (r.aiLabels ?? []).map((l) => `${esc(l.label)} ${Math.round(l.confidence * 100)}%`).join(' · ') || '—'],
    ['Text', esc(r.ocrText).replaceAll('\n', ' / ') || '—'],
    ['Embedding', `${esc(r.embeddingModel ?? 'none')} (768 floats, kept on the device for search)`],
  ]);

  if (r.attached?.length) {
    $('attached-panel').hidden = false;
    $('attached-title').textContent = `+${r.attached.length} attached capture${r.attached.length > 1 ? 's' : ''}`;
    $('attached').innerHTML = r.attached.map((a) =>
      `<a href="report.html?id=${encodeURIComponent(a.id)}" title="${esc(a.createdBy)} · ${ago(a.createdAt)}"><img class="thumb" src="${thumbUrl(a)}" alt=""></a>`).join('');
  }

  $('status-buttons').innerHTML = Object.entries(STATUS_LABEL).map(([value, label]) =>
    `<button class="btn ${value === r.status ? 'primary' : ''}" data-v="${value}" ${value === r.status ? 'disabled' : ''}>${label}</button>`).join('');
}

$('status-buttons').onclick = async (e) => {
  const status = e.target.dataset?.v;
  if (!status) return;
  $('status-msg').textContent = 'Saving…';
  const res = await fetch(`/api/reports/${encodeURIComponent(id)}/status`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status }),
  });
  const body = await res.json();
  $('status-msg').textContent = res.ok ? `Saved as ${STATUS_LABEL[status]}. Syncing to the crew's phones.` : `Failed: ${body.error}`;
  if (res.ok) load();
};

$('verify').onclick = async () => {
  $('verify').disabled = true;
  const v = await (await fetch(`/api/verify/${encodeURIComponent(id)}`)).json();
  $('verify').disabled = false;
  const stamp = $('stamp');
  stamp.hidden = false;
  stamp.className = `stamp ${v.verified ? 'ok' : 'bad'}`;
  stamp.textContent = v.verified ? 'VERIFIED' : 'MISMATCH';
  $('verify-detail').textContent = v.error ? v.error :
    `server bytes: ${v.byteLength.toLocaleString()} · sha256 ${v.actual}`;
  $('photo').src = `/api/photo/${encodeURIComponent(id)}?t=${Date.now()}`;
};

load();
