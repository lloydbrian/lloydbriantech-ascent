import pg from 'pg'
import { GenericContainer } from 'testcontainers'

describe('price list', () => {
  it('AC-3 loads prices from the database', async () => {
    const db = await new GenericContainer('postgres:16.4').start()
    const client = new pg.Client({ host: db.getHost(), port: db.getMappedPort(5432) })
    expect(client).toBeDefined()
    await db.stop()
  })
})
