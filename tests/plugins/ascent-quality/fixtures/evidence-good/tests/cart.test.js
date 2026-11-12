import { test } from 'node:test';
import assert from 'node:assert';
import { total } from '../src/cart.js';

test('total adds price times quantity', () => {
  assert.strictEqual(total([{ price: 2, qty: 3 }, { price: 1, qty: 1 }]), 7);
});
