"""issue_refund: never more than MAX_REFUND, and only after a person approves."""
MAX_REFUND = 50


def issue_refund(order: str, amount: float, approved_by: str) -> None:
    if not approved_by:
        raise PermissionError("issue_refund needs a person's approval")
    if amount > MAX_REFUND:
        raise ValueError("issue_refund is capped at MAX_REFUND")
