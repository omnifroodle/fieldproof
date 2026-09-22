// Creates the evidence scope, its collections, and the query indexes on Capella, then prints the manual checklist.
// Run from dashboard/: npm run setup   (reads dashboard/.env)
import { cluster, ping, close } from '../dashboard/lib/couchbase.js';

const bucket = process.env.CB_BUCKET ?? 'fieldproof';

// Talking point: the same scope and collections exist on the phone, so data maps one to one.
const keyspaces = [
  `CREATE SCOPE \`${bucket}\`.evidence IF NOT EXISTS`,
  `CREATE COLLECTION \`${bucket}\`.evidence.reports IF NOT EXISTS`,
  `CREATE COLLECTION \`${bucket}\`.evidence.photos IF NOT EXISTS`,
];

// Talking point: SQL++ indexes on the cluster, the same language the phone uses locally.
const indexes = [
  // Dashboard list and map: filter by district and status, newest first.
  `CREATE INDEX idx_reports_list IF NOT EXISTS ON \`${bucket}\`.evidence.reports(district, status, createdAt) WHERE type = "report"`,
  // Find the photo document for a report.
  `CREATE INDEX idx_photos_report IF NOT EXISTS ON \`${bucket}\`.evidence.photos(reportId)`,
  // Dev convenience only: lets ad-hoc queries run without a matching index. Do not ship this.
  `CREATE PRIMARY INDEX IF NOT EXISTS ON \`${bucket}\`.evidence.reports`,
];

try {
  console.log('SELECT 1 ->', await ping());
  const c = await cluster();
  for (const sql of keyspaces) {
    await c.query(sql);
    console.log('ok:', sql);
  }
  for (const sql of indexes) {
    await c.query(sql);
    console.log('ok:', sql.split(' ON ')[0]);
  }
  console.log(`
Manual steps in the Capella UI (see README):
  1. App Services: App Endpoint "fieldproof" on bucket ${bucket}, scope evidence, collections reports + photos. Resume it.
  2. Access and Validation: paste appservices/sync-function-reports.js and sync-function-photos.js.
  3. App Users: crew-valley (district.valley), crew-tuolumne (district.tuolumne), supervisor (*).
  4. Connect: copy the public URL into ios/FieldProof/Config/Secrets.plist; create an Admin credential for dashboard/.env.`);
} catch (err) {
  console.error('setup failed:', err.message);
  process.exitCode = 1;
} finally {
  await close();
}
