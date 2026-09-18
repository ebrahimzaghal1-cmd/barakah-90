// REST adapter shared by the Worker and local emulator integration tests.
// Document fields are kept separate from trusted Firestore metadata.
export class SecurityError extends Error {
  constructor(status, code, message = 'تعذر تنفيذ العملية بأمان. حاول مجددًا.') {
    super(message); this.status = status; this.code = code;
  }
}
export function requireValue(condition, code, message, status = 400) {
  if (!condition) throw new SecurityError(status, code, message);
}
export function documentId(value) {
  requireValue(typeof value === 'string' && value.length > 0 && value.length <= 512 && !value.includes('/') && !['.', '..'].includes(value), 'invalid-id', 'المعرّف غير صالح.');
  return value;
}
export function encodeValue(value) {
  if (value === null) return { nullValue: null };
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encodeValue) } };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    requireValue(Number.isFinite(value), 'invalid-number', 'قيمة رقمية غير صالحة.');
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'object') return { mapValue: { fields: encodeFields(value) } };
  return { stringValue: String(value) };
}
function encodeFields(data) { return Object.fromEntries(Object.entries(data).filter(([, v]) => v !== undefined).map(([k, v]) => [k, encodeValue(v)])); }
function decodeValue(v) {
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('stringValue' in v) return v.stringValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields || {});
  return null;
}
function decodeFields(data) { return Object.fromEntries(Object.entries(data).map(([k, v]) => [k, decodeValue(v)])); }
function record(doc) { return { id: doc.name.split('/').pop(), version: doc.updateTime, data: decodeFields(doc.fields || {}) }; }
export function createFirestoreStore({ baseUrl, token, fetchImpl = fetch }) {
  const projectPath = baseUrl.slice(baseUrl.indexOf('/projects/') + 1);
  const headers = { authorization: `Bearer ${token}`, 'content-type': 'application/json' };
  async function call(url, body, missing = false) {
    const response = await fetchImpl(url, { method: body === undefined ? 'GET' : 'POST', headers, ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    if (missing && response.status === 404) return null;
    if (response.status === 409 || response.status === 412) throw new SecurityError(409, 'transaction-conflict');
    // Never include request data, server response bodies, tokens or credentials.
    if (!response.ok) throw new SecurityError(502, 'store-unavailable');
    return response.json();
  }
  const urlFor = path => `${baseUrl}/${path.split('/').map(encodeURIComponent).join('/')}`;
  const makeReader = transaction => ({
    async get(path) {
      const value = await call(`${urlFor(path)}${transaction ? `?transaction=${encodeURIComponent(transaction)}` : ''}`, undefined, true);
      return value ? record(value) : null;
    },
    async query(collection, equals = {}) {
      const filters = Object.entries(equals).map(([key, value]) => ({ fieldFilter: { field: { fieldPath: key }, op: 'EQUAL', value: encodeValue(value) } }));
      const rows = await call(`${baseUrl}:runQuery`, { structuredQuery: { from: [{ collectionId: collection }],
        ...(filters.length ? { where: filters.length === 1 ? filters[0] : { compositeFilter: { op: 'AND', filters } } } : {}) }, ...(transaction ? { transaction } : {}) });
      // No silent 100-document limit: omitted reservations must never allow overlap.
      return rows.filter(row => row.document).map(row => record(row.document));
    },
  });
  const reader = makeReader(null);
  return { ...reader,
    async runTransaction(work) {
      for (let attempt = 0; attempt < 5; attempt++) {
        const { transaction } = await call(`${baseUrl}:beginTransaction`, {});
        const writes = [];
        const tx = { ...makeReader(transaction),
          set(path, data, { merge = false, remove = [] } = {}) {
            const write = { update: { name: `${projectPath}/${path}`, fields: encodeFields(data) } };
            if (merge) write.updateMask = { fieldPaths: [...Object.keys(data), ...remove] };
            writes.push(write);
          },
          delete(path) { writes.push({ delete: `${projectPath}/${path}` }); },
        };
        try {
          const result = await work(tx);
          await call(`${baseUrl}:commit`, { transaction, writes });
          return result;
        } catch (error) {
          await call(`${baseUrl}:rollback`, { transaction }).catch(() => {});
          if (error.code !== 'transaction-conflict') throw error;
        }
      }
      throw new SecurityError(409, 'transaction-conflict', 'وصل تعديل متزامن؛ حاول مجددًا.');
    },
  };
}
