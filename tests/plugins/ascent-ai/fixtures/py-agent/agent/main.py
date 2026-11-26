"""Support assistant: drafts a reply to a ticket, tags it, and can refund an order."""
import os

from openai import OpenAI

from agent.config import MODEL

client = OpenAI(base_url=os.environ["LLM_GATEWAY_URL"])

TOOLS = [
    {"type": "function", "function": {"name": "tag_ticket", "description": "Add a tag to a ticket.",
                                      "parameters": {"type": "object", "properties": {"tag": {"type": "string"}}}}},
    {"type": "function", "function": {"name": "issue_refund", "description": "Refund an order, up to the limit.",
                                      "parameters": {"type": "object", "properties": {"order": {"type": "string"}}}}},
]


def draft_reply(ticket: str) -> str:
    if os.environ.get("SUPPORT_AI_ENABLED", "1") != "1":
        return ""
    response = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": ticket}],
        tools=TOOLS,
        max_tokens=800,
    )
    return response.choices[0].message.content or ""
