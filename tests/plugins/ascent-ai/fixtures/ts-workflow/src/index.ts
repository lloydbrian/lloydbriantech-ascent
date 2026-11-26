// Ticket router: one fixed sequence of model calls (classify, then draft).
import Anthropic from "@anthropic-ai/sdk";
import { MODEL } from "./config";

const client = new Anthropic();

export async function route(ticket: string): Promise<string> {
  if (process.env.ROUTER_AI_ENABLED === "0") return "";
  const label = await client.messages.create({
    model: MODEL,
    max_tokens: 50,
    messages: [{ role: "user", content: `Classify: ${ticket}` }],
  });
  const draft = await client.messages.create({ model: MODEL, max_tokens: 600, messages: [{ role: "user", content: ticket }] });
  return label.content[0].type === "text" && draft.content[0].type === "text" ? draft.content[0].text : "";
}
