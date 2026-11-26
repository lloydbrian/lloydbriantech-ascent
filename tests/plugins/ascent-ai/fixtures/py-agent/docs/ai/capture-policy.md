# Capture policy: support-assistant

What the traces keep of each model call.

- Stored: the prompt template name, the model, token counts, latency and the tool calls, for 30 days.
- Redacted: names, emails and order numbers in ticket text, replaced before the span is written.
- Dropped: the full ticket text and the model's reply are never stored.
