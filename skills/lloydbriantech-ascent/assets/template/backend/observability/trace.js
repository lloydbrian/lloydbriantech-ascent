import { randomUUID } from 'node:crypto';

// W3C TraceContext utilities per observability-contract.md.
//
// TraceContext format: 00-<trace-id>-<span-id>-<flags>
//   trace-id: 32 hex chars (128-bit)
//   span-id:  16 hex chars (64-bit)
//   flags:    2 hex chars (sampled = 01)
//
// These utilities support:
//   - Extracting trace-id from an incoming traceparent header
//   - Generating a new traceparent for outbound requests
//   - Creating child spans for external service calls

const TRACEPARENT_REGEX = /^00-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/;

export function parseTraceparent(header) {
  if (!header) return null;
  const match = header.match(TRACEPARENT_REGEX);
  if (!match) return null;
  return {
    traceId: match[1],
    spanId: match[2],
    flags: match[3],
  };
}

export function generateTraceId() {
  return randomUUID().replace(/-/g, '');
}

export function generateSpanId() {
  return randomUUID().replace(/-/g, '').slice(0, 16);
}

export function formatTraceparent({ traceId, spanId, flags = '01' }) {
  return `00-${traceId}-${spanId}-${flags}`;
}

export function createChildSpan(parentTraceId) {
  return {
    traceId: parentTraceId,
    spanId: generateSpanId(),
    flags: '01',
  };
}
