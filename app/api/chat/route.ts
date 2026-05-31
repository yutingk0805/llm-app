import { runChat, type ChatTurn, type ModelChoice } from "@/app/lib/bedrock";

const VALID_MODELS: ModelChoice[] = ["haiku-4.5", "nova-lite"];

type ChatRequest = {
  messages?: ChatTurn[];
  guardrails?: boolean;
  insecurePrompt?: boolean;
  model?: ModelChoice;
};

export async function POST(request: Request) {
  let body: ChatRequest;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const messages = body.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return Response.json(
      { error: "`messages` must be a non-empty array" },
      { status: 400 },
    );
  }

  // Promptfoo and the UI can both flip these. Both default to the "safe" choice
  // (guardrails OFF, hardened prompt) so the insecure path is always explicit.
  const guardrails = body.guardrails === true;
  const insecurePrompt = body.insecurePrompt === true;
  // Default to the strong model unless a valid weaker one is explicitly requested.
  const model: ModelChoice = VALID_MODELS.includes(body.model as ModelChoice)
    ? (body.model as ModelChoice)
    : "haiku-4.5";

  try {
    const result = await runChat(messages, {
      guardrailsOn: guardrails,
      insecurePrompt,
      model,
    });
    return Response.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Unknown error";
    return Response.json(
      { error: `Bedrock call failed: ${message}` },
      { status: 502 },
    );
  }
}
