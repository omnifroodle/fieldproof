// Couchbase Node SDK access to the Capella cluster. All SQL++ used by the dashboard lives in this file.
import couchbase from 'couchbase';

let clusterPromise;

// Talking point: one connection string and a database credential; the SDK finds every node in the cluster.
export function cluster() {
  clusterPromise ??= couchbase.connect(process.env.CB_CONN_STR, {
    username: process.env.CB_USERNAME,
    password: process.env.CB_PASSWORD,
    configProfile: 'wanDevelopment', // longer timeouts for a laptop talking to the cloud
  });
  return clusterPromise;
}

// Smallest possible round trip through the Query service.
export async function ping() {
  const result = await (await cluster()).query('SELECT 1 AS ok');
  return result.rows[0];
}

export async function close() {
  if (clusterPromise) await (await clusterPromise).close();
  clusterPromise = undefined;
}
