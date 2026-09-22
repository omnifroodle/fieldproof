// Evidence check on the server: hash the photo bytes App Services holds and compare with the hash the phone
// recorded at capture.
import { createHash } from 'node:crypto';
import * as appservices from './appservices.js';

/** Pure comparison, unit tested without a network. */
export function compareHash(bytes, expected) {
  const actual = createHash('sha256').update(bytes).digest('hex');
  return { verified: actual === String(expected).toLowerCase(), expected, actual, byteLength: bytes.length };
}

// Talking point: the hash was computed on the device at capture, so the server cannot silently alter evidence.
export async function verifyReport(id) {
  const report = await appservices.getDoc(appservices.keyspace('reports'), id);
  const bytes = await appservices.getAttachment(appservices.keyspace('photos'), report.photoDocId, 'photo');
  return compareHash(bytes, report.imageHash);
}
