"""The agent loop: the model picks the next tool until it answers, within the limits."""
from agent.config import MAX_STEPS, MODEL
from agent.main import TOOLS, client


def run(ticket: str) -> str:
    messages = [{"role": "user", "content": ticket}]
    for _ in range(MAX_STEPS):
        response = client.chat.completions.create(model=MODEL, messages=messages, tools=TOOLS, max_tokens=800)
        choice = response.choices[0]
        if choice.finish_reason != "tool_calls":
            return choice.message.content or ""
        messages.append(choice.message)
    return "I could not finish this one; a person will reply."
