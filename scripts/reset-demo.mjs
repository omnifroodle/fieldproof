// Deletes every report and photo document so the demo starts clean. Deletions sync down to the phones.
// Run from dashboard/: npm run reset
import * as db from '../dashboard/lib/couchbase.js';
import * as as from '../dashboard/lib/appservices.js';

// Talking point: deletes go through App Services like any other write, so each phone receives a tombstone
// and removes the report locally on its next sync.
async function wipe(collection) {
  const ks = as.keyspace(collection);
  const ids = await db.allIds(collection);
  let deleted = 0;
  for (let i = 0; i < ids.length; i += 8) {
    await Promise.all(ids.slice(i, i + 8).map(async (id) => {
      try {
        const { _rev } = await as.getDoc(ks, id);
        await as.deleteDoc(ks, id, _rev);
        deleted++;
      } catch (err) {
        if (err.status !== 404) console.error(`  ${id}: ${err.message}`);
      }
    }));
  }
  console.log(`${collection}: deleted ${deleted} of ${ids.length}`);
}

try {
  await wipe('reports');
  await wipe('photos');
  console.log('Done. On the phone: Settings → Load sample reports to reseed.');
} finally {
  await db.close();
}
