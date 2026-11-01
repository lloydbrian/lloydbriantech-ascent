// Core rule: cart totals and refunds.
export function total(lines) {
  return lines.reduce((sum, line) => sum + line.price * line.qty, 0)
}

export function refund(charged, amount) {
  return charged - amount
}
