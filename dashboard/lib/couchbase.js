// Couchbase Node SDK access to the Capella cluster. All SQL++ used by the dashboard lives in this file.
import couchbase from 'couchbase';

let clusterPromise;
const bucket = () => process.env.CB_BUCKET ?? 'fieldproof';
const reports = () => `\`${bucket()}\`.evidence.reports`;

// Talking point: one connection string and a database credential; the SDK finds every node in the cluster.
export function cluster() {
  clusterPromise ??= couchbase.connect(process.env.CB_CONN_STR, {
    username: process.env.CB_USERNAME,
    password: process.env.CB_PASSWORD,
    configProfile: 'wanDevelopment', // longer timeouts for a laptop talking to the cloud
  });
  return clusterPromise;
}

async function query(sql, parameters = {}) {
  // Talking point: RequestPlus waits for the index to include every write so far, so a report
  // that just synced from a phone is on the map at the next poll.
  const result = await (await cluster()).query(sql, {
    parameters,
    scanConsistency: couchbase.QueryScanConsistency.RequestPlus,
  });
  return result.rows;
}

// Smallest possible round trip through the Query service.
export async function ping() {
  return (await query('SELECT 1 AS ok'))[0];
}

/** Map and list: every parent report, newest first. Attached captures ride along on their parent. */
export function listReports({ district, status } = {}) {
  return query(`
    SELECT META().id AS id, district, status, category, createdAt, createdBy, notes,
           location.lat AS lat, location.lon AS lon,
           thumbnail.digest AS thumb,                         -- blob metadata; bytes come from App Services
           ARRAY_LENGTH(IFMISSINGORNULL(relatedReportIds, [])) AS attached
    FROM ${reports()}
    WHERE type = "report"
      AND district IS NOT MISSING                              -- lets idx_reports_list serve the query
      AND attachedTo IS MISSING                                -- attached captures are not separate pins
      AND ($district IS NULL OR district = $district)
      AND ($status IS NULL OR status = $status)
    ORDER BY createdAt DESC`, { district: district ?? null, status: status ?? null });
}

/** Detail page: the report without its 768-float embedding, plus the captures attached to it. */
export async function getReport(id) {
  const [report] = await query(`
    SELECT META(r).id AS id, OBJECT_REMOVE(OBJECT_REMOVE(r, "embedding"), "thumbnail") AS doc
    FROM ${reports()} AS r
    USE KEYS $id`, { id });
  if (!report) return null;
  const attached = await query(`
    SELECT META().id AS id, createdAt, createdBy, thumbnail.digest AS thumb
    FROM ${reports()}
    WHERE type = "report" AND attachedTo = $id
    ORDER BY createdAt`, { id });
  return { ...report.doc, id: report.id, attached };
}

/** Every app document id in a collection (the Capella Public REST API does not allow _all_docs).
 *  Skips `_sync:` ids: App Services keeps attachment bodies and metadata there and manages them itself. */
export function allIds(collection) {
  return query(`SELECT RAW META().id FROM \`${bucket()}\`.evidence.${collection} WHERE SUBSTR(META().id, 0, 6) != "_sync:"`);
}

export async function close() {
  if (clusterPromise) await (await clusterPromise).close();
  clusterPromise = undefined;
}
