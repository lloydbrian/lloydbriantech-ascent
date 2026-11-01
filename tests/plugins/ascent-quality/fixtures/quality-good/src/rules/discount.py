"""Core rule: percentage discounts."""


def apply(price, pct):
    return round(price * (1 - pct / 100), 2)
