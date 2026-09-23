// Map + list. Polls /api/reports every 3 s; new pins pulse once.
import { STATUS_LABEL, CATEGORY_LABEL, thumbUrl, ago, esc, pinIcon } from './common.js';

const filters = { district: '', status: '' };
const markers = new Map(); // id -> { marker, status }
let firstLoad = true;

// Leaflet with OpenStreetMap tiles (no API key; light demo use per the OSM tile policy),
// warmed toward the poster palette in CSS. CARTO basemaps now require a key (REFERENCE.md §7.4).
const map = L.map('map', { zoomControl: true }).setView([37.7445, -119.586], 14);
L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
  attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors', maxZoom: 19,
}).addTo(map);

function chips(el, key, options) {
  el.innerHTML = options.map(([value, label]) =>
    `<button class="chip ${filters[key] === value ? 'on' : ''}" data-v="${value}">${label}</button>`).join('');
  el.onclick = (e) => {
    const v = e.target.dataset?.v;
    if (v === undefined) return;
    filters[key] = v;
    render();
    load();
  };
}

function render() {
  chips(document.getElementById('districts'), 'district', [['', 'All districts'], ['valley', 'Valley'], ['tuolumne', 'Tuolumne']]);
  chips(document.getElementById('statuses'), 'status', [['', 'Any status'], ...Object.entries(STATUS_LABEL)]);
}

function card(r) {
  const extra = r.attached ? ` · +${r.attached} attached capture${r.attached > 1 ? 's' : ''}` : '';
  return `<a class="card" href="report.html?id=${encodeURIComponent(r.id)}">
    <img src="${thumbUrl(r)}" alt="" loading="lazy">
    <div style="flex:1">
      <div class="row"><h3>${CATEGORY_LABEL[r.category] ?? r.category}</h3><span class="pill ${r.status}">${STATUS_LABEL[r.status]}</span></div>
      <p>${esc(r.notes) || '<i>No notes</i>'}</p>
      <div class="meta">${ago(r.createdAt)} · ${esc(r.district)} · ${esc(r.createdBy)}${extra}</div>
    </div></a>`;
}

function popup(r) {
  return `<div class="popup"><img src="${thumbUrl(r)}" alt="">
    <div><b>${CATEGORY_LABEL[r.category] ?? r.category}</b><br>${ago(r.createdAt)}<br>
    <span class="pill ${r.status}">${STATUS_LABEL[r.status]}</span><br>
    <a href="report.html?id=${encodeURIComponent(r.id)}">Open report</a></div></div>`;
}

function updatePins(reports) {
  const seen = new Set();
  for (const r of reports) {
    if (typeof r.lat !== 'number') continue;
    seen.add(r.id);
    const known = markers.get(r.id);
    if (known && known.status === r.status) continue;
    known?.marker.remove();
    const marker = L.marker([r.lat, r.lon], { icon: pinIcon(r.status, !firstLoad && !known) }).bindPopup(popup(r)).addTo(map);
    markers.set(r.id, { marker, status: r.status });
  }
  for (const [id, { marker }] of markers) if (!seen.has(id)) { marker.remove(); markers.delete(id); }
}

async function load() {
  try {
    const qs = new URLSearchParams(Object.entries(filters).filter(([, v]) => v));
    const reports = await (await fetch(`/api/reports?${qs}`)).json();
    if (!Array.isArray(reports)) throw new Error(reports.error ?? 'bad response');
    document.getElementById('list').innerHTML = reports.map(card).join('') || '<div class="empty">NO REPORTS ON THIS TRAIL YET</div>';
    updatePins(reports);
    firstLoad = false;
    document.getElementById('updated').textContent = `Last update ${new Date().toLocaleTimeString()} · ${reports.length} reports`;
  } catch (err) {
    document.getElementById('updated').textContent = `Cannot reach Capella: ${err.message}`;
  }
}

render();
load();

// Talking point: the server holds a longpoll on the App Services changes feed, so a report a phone just
// synced lands on this map in about a second. The slow interval is only a safety net if the stream drops.
const stream = new EventSource('/api/stream');
let coalesce;                                   // a burst of 30 seeded reports is one redraw, not thirty
stream.onmessage = () => { clearTimeout(coalesce); coalesce = setTimeout(load, 400); };
setInterval(load, 15000);
