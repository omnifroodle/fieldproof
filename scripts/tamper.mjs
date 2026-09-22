// Demo finale: swap the photo behind a report for a different image, as an insider with valid access might.
// The report still carries the SHA-256 the phone computed at capture, so Verify now shows MISMATCH.
// Run from dashboard/: node --env-file=.env ../scripts/tamper.mjs <reportId>     (undo: npm run reset)
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import * as as from '../dashboard/lib/appservices.js';

const reportId = process.argv[2];
if (!reportId?.startsWith('report::')) {
  console.error('usage: node --env-file=.env ../scripts/tamper.mjs report::<id>');
  process.exit(1);
}
const sha = (b) => createHash('sha256').update(b).digest('hex');
const ks = as.keyspace('photos');
const photoId = reportId.replace('report::', 'photo::');

const report = await as.getDoc(as.keyspace('reports'), reportId);
const before = await as.getAttachment(ks, photoId, 'photo');
const fake = await readFile(new URL('./assets/tamper.jpg', import.meta.url));

// 1. Replace the attachment bytes (a Couchbase Lite blob syncs as attachment "blob_/photo").
const doc = await as.getDoc(ks, photoId);
const put = await as.putAttachment(ks, photoId, 'photo', fake, doc._rev);

// 2. Point the document's `photo` blob at the new bytes, so phones pull the swapped photo too.
const updated = await as.getDoc(ks, photoId);
const att = updated._attachments['blob_/photo'];
const { _id, _rev, _cv, ...body } = updated;
body.photo = { '@type': 'blob', content_type: att.content_type, digest: att.digest, length: att.length };
await as.putDoc(ks, photoId, body, put.rev);

console.log(`report      ${reportId}`);
console.log(`recorded    ${report.imageHash}   (hashed on the phone at capture)`);
console.log(`before      ${sha(before)}   ${before.length} bytes`);
console.log(`after       ${sha(fake)}   ${fake.length} bytes  <- tampered`);
console.log('Dashboard: Verify now shows MISMATCH. Phone: Recompute shows MISMATCH after it syncs.');
