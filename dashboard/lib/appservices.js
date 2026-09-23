// App Services Public REST (port 4984), used as the `supervisor` app user.
// Talking point: the dashboard writes through the same sync function as the phones. No admin key anywhere.

const base = () => process.env.APPSERVICES_URL.replace(/^wss?:/, 'https:').replace(/\/+$/, '').replace(/\/fieldproof$/, '');
const auth = () => 'Basic ' + Buffer.from(`${process.env.APPSERVICES_USER}:${process.env.APPSERVICES_PASSWORD}`).toString('base64');

/** `fieldproof.evidence.reports` style keyspace: endpoint.scope.collection */
export const keyspace = (collection) => `${process.env.APPSERVICES_ENDPOINT ?? 'fieldproof'}.evidence.${collection}`;

/** Couchbase Lite blobs sync as attachments named `blob_/<property>`; the slash must be encoded in the URL. */
export const blobName = (property) => encodeURIComponent(`blob_/${property}`);

async function call(method, path, { body, type = 'application/json', raw = false } = {}) {
  const res = await fetch(base() + path, {
    method,
    headers: { Authorization: auth(), ...(body ? { 'Content-Type': type } : {}) },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw Object.assign(new Error(`${method} ${path} → ${res.status} ${text.slice(0, 200)}`), { status: res.status });
  }
  return raw ? Buffer.from(await res.arrayBuffer()) : res.json();
}

const docPath = (ks, id) => `/${ks}/${encodeURIComponent(id)}`;

export const getDoc = (ks, id) => call('GET', docPath(ks, id));

/** Full-document update. `body` must carry `_attachments` stubs so blobs are kept. */
export const putDoc = (ks, id, body, rev) =>
  call('PUT', `${docPath(ks, id)}?rev=${encodeURIComponent(rev)}`, { body: JSON.stringify(body) });

export const deleteDoc = (ks, id, rev) => call('DELETE', `${docPath(ks, id)}?rev=${encodeURIComponent(rev)}`);

export const getAttachment = (ks, id, property) => call('GET', `${docPath(ks, id)}/${blobName(property)}`, { raw: true });

export const putAttachment = (ks, id, property, bytes, rev, type = 'image/jpeg') =>
  call('PUT', `${docPath(ks, id)}/${blobName(property)}?rev=${encodeURIComponent(rev)}`, { body: bytes, type });

/** Talking point: App Services' changes feed. With `feed=longpoll` the request stays open until a document
 *  actually changes, so the dashboard reacts to a phone's sync instead of asking Capella every few seconds. */
export const changes = (ks, since = '0', timeoutMs = 25_000) =>
  call('GET', `/${ks}/_changes?feed=longpoll&since=${encodeURIComponent(since)}&timeout=${timeoutMs}`);
