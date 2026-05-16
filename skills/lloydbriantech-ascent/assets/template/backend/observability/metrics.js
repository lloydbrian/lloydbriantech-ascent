// Basic metrics counter scaffold per observability-contract.md.
//
// Phase 2 ships an in-memory counter for request counts by method + route + status.
// A production metrics pipeline (Prometheus client, /metrics endpoint) wires into
// this scaffold in a future phase when the project adds observability collection.
//
// The interface is stable: increment(method, route, status) is the contract.
// The backend (in-memory map vs. prom-client histogram) is swappable.

const counters = new Map();

function key(method, route, status) {
  return `${method}|${route}|${status}`;
}

export function increment(method, route, status) {
  const k = key(method, route, status);
  counters.set(k, (counters.get(k) || 0) + 1);
}

export function getSnapshot() {
  const result = [];
  for (const [k, count] of counters.entries()) {
    const [method, route, status] = k.split('|');
    result.push({ method, route, status: parseInt(status, 10), count });
  }
  return result;
}

export function reset() {
  counters.clear();
}
