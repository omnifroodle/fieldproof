// FieldProof supervisor dashboard: a map and list of field reports, photo evidence, and hash verification.
import express from 'express';
import { fileURLToPath } from 'node:url';
import * as db from './lib/couchbase.js';
import * as appservices from './lib/appservices.js';
import { verifyReport } from './lib/verify.js';

const app = express();
app.use(express.json());
app.use(express.static(fileURLToPath(new URL('./public', import.meta.url))));

const STATUSES = ['open', 'in_progress', 'resolved'];
const thumbs = new Map(); // `${id}|${digest}` -> JPEG bytes; the digest changes when the thumbnail does

const route = (fn) => async (req, res) => {
  try {
    await fn(req, res);
  } catch (err) {
    console.error(req.method, req.path, err.message);
    res.status(err.status === 404 ? 404 : 502).json({ error: err.message });
  }
};

const sendJpeg = (res, bytes, cache) =>
  res.set({ 'Content-Type': 'image/jpeg', 'Cache-Control': cache }).send(bytes);

// Talking point: the list comes from SQL++ on the Capella cluster, the system of record.
app.get('/api/reports', route(async (req, res) => {
  const { district, status } = req.query;
  res.json(await db.listReports({ district: district || undefined, status: status || undefined }));
}));

app.get('/api/reports/:id', route(async (req, res) => {
  const report = await db.getReport(req.params.id);
  report ? res.json(report) : res.status(404).json({ error: 'not found' });
}));

// Photo bytes live in App Services as attachments; always fetched fresh so a tamper shows up at once.
app.get('/api/photo/:id', route(async (req, res) => {
  const photoId = req.params.id.replace(/^report::/, 'photo::');
  sendJpeg(res, await appservices.getAttachment(appservices.keyspace('photos'), photoId, 'photo'), 'no-store');
}));

app.get('/api/thumbnail/:id', route(async (req, res) => {
  const key = `${req.params.id}|${req.query.d ?? ''}`;
  if (!thumbs.has(key)) {
    thumbs.set(key, await appservices.getAttachment(appservices.keyspace('reports'), req.params.id, 'thumbnail'));
  }
  sendJpeg(res, thumbs.get(key), 'public, max-age=3600');
}));

app.get('/api/verify/:id', route(async (req, res) => {
  res.json(await verifyReport(req.params.id));
}));

// Talking point: a status change is a normal document update through App Services, so it syncs down to
// the crew's phones and passes the same sync function.
app.post('/api/reports/:id/status', route(async (req, res) => {
  const { status } = req.body ?? {};
  if (!STATUSES.includes(status)) return res.status(400).json({ error: `status must be one of ${STATUSES}` });
  const ks = appservices.keyspace('reports');
  const { _id, _rev, _cv, ...doc } = await appservices.getDoc(ks, req.params.id);
  const result = await appservices.putDoc(ks, req.params.id, { ...doc, status }, _rev);
  res.json({ id: req.params.id, status, rev: result.rev });
}));

// Talking point: one longpoll per open dashboard, held against App Services. The browser is told
// "something changed" and refetches; nothing polls Capella on a timer.
app.get('/api/stream', async (req, res) => {
  res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache', Connection: 'keep-alive' });
  res.flushHeaders();
  let since = req.query.since ?? '0';   // the first poll returns at once and hands back the current sequence
  let open = true;
  req.on('close', () => { open = false; });
  while (open) {
    try {
      const feed = await appservices.changes(appservices.keyspace('reports'), since);
      since = feed.last_seq ?? since;
      res.write(feed.results?.length ? `data: ${feed.results.length}\n\n` : ': waiting\n\n');
    } catch (err) {
      if (!open) break;
      res.write(`event: stalled\ndata: ${err.message}\n\n`);
      await new Promise((done) => setTimeout(done, 5000));
    }
  }
  res.end();
});

const port = Number(process.env.PORT ?? 3000);
const server = app.listen(port, () => console.log(`FieldProof dashboard on http://localhost:${port}`));

process.on('SIGINT', async () => {
  server.close();
  await db.close();
  process.exit(0);
});
