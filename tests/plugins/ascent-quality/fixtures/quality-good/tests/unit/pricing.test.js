import { total, refund } from '../../src/rules/pricing.js'

describe('pricing', () => {
  it('AC-1 sums price times quantity', () => {
    expect(total([{ price: 2, qty: 3 }, { price: 1, qty: 1 }])).toBe(7)
  })

  it('AC-2.1 keeps the rest charged after a partial refund', () => {
    expect(refund(10, 4)).toBe(6)
  })

  // Pending the multi-currency rules, see issue #12.
  it.skip('converts currencies', () => {})
})
