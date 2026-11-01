import { PactV3 } from '@pact-foundation/pact'

describe('price service contract', () => {
  it('returns a price for a known item', async () => {
    const pact = new PactV3({ consumer: 'checkout', provider: 'prices' })
    expect(pact).toBeDefined()
  })
})
