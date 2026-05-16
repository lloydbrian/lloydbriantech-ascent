import { Router } from 'express';
import { listItems, createItem } from '../controllers/items.js';

export const itemRoutes = Router();

// GET /api/items — list all items
itemRoutes.get('/items', listItems);

// POST /api/items — create a new item
itemRoutes.post('/items', createItem);
