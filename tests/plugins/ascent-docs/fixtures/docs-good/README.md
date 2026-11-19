# Catalog service

Version: 1.4.0

A small service that lists and searches the product catalog.

## Getting started

You need Node.js >= 20 and Docker.

```bash
make dev
npm run build
```

Configuration is read from `DATABASE_URL` and `PORT`; see the [configuration reference](docs/reference/config.md#environment).

## Documentation

- [Developer guide](docs/guide.md): how the code is laid out and how to change it
- [Contributing](CONTRIBUTING.md)

The entry point is `src/app.js`.
