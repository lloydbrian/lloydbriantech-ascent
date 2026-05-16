import * as itemsService from '../services/items.js';

// Controller layer: validate input, shape response.
// No business logic here — that belongs in services/.

export function listItems(req, res, next) {
  try {
    const items = itemsService.getAll();
    res.json({ data: items });
  } catch (err) {
    next(err);
  }
}

export function createItem(req, res, next) {
  try {
    const { name } = req.body;

    if (!name || typeof name !== 'string') {
      return res.status(400).json({
        error: { message: 'name is required and must be a string', status: 400 },
      });
    }

    const trimmed = name.trim();
    if (trimmed.length === 0) {
      return res.status(400).json({
        error: { message: 'name must not be empty', status: 400 },
      });
    }

    if (trimmed.length > 200) {
      return res.status(400).json({
        error: { message: 'name must be 200 characters or fewer', status: 400 },
      });
    }

    const item = itemsService.create({ name: trimmed });
    res.status(201).json({ data: item });
  } catch (err) {
    next(err);
  }
}
