import { test, expect } from '@playwright/test'

test('AC-1 checkout shows the cart total', async ({ page }) => {
  await page.goto('/checkout')
  await expect(page.getByText('Total')).toBeVisible()
})
