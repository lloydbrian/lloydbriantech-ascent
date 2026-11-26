"""A plain web handler; no model."""


def handler(event: dict) -> dict:
    return {"statusCode": 200, "body": "ok"}
