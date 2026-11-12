// Checkout at peak: 60 iterations a second for five minutes (peak_rps is 50).
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  scenarios: {
    peak: {
      executor: 'constant-arrival-rate',
      rate: 60,
      timeUnit: '1s',
      duration: '5m',
      preAllocatedVUs: 100,
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<400', 'p(99)<1200'],
    'http_req_duration{name:pay}': ['p(95)<450'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get(`${__ENV.BASE_URL}/checkout`, { tags: { name: 'pay' } });
  check(res, { 'status is 200': (r) => r.status === 200 });
}
