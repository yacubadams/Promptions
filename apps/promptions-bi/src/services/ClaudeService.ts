export interface ChatMessage {
    role: "user" | "assistant" | "system";
    content: string;
}

const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 4000;

function splitSystemAndMessages(messages: ChatMessage[]): {
    system: string | undefined;
    userMessages: { role: "user" | "assistant"; content: string }[];
} {
    const systemMsg = messages.find((m) => m.role === "system");
    const userMessages = messages
        .filter((m) => m.role !== "system")
        .map((m) => ({ role: m.role as "user" | "assistant", content: m.content }));
    return { system: systemMsg?.content, userMessages };
}

export class ClaudeService {
    private apiKey: string;

    constructor() {
        this.apiKey = (import.meta as any).env.VITE_ANTHROPIC_API_KEY ?? "";
    }

    async sendMessage(messages: ChatMessage[]): Promise<string> {
        const { system, userMessages } = splitSystemAndMessages(messages);
        const body: Record<string, unknown> = { model: MODEL, max_tokens: MAX_TOKENS, messages: userMessages };
        if (system) body.system = system;
        const response = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "x-api-key": this.apiKey,
                "anthropic-version": "2023-06-01",
                "anthropic-dangerous-direct-browser-access": "true",
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) {
            const err = await response.text();
            throw new Error(`Claude API error ${response.status}: ${err}`);
        }
        const data = await response.json();
        return data.content?.[0]?.text ?? "";
    }

    async streamChat(
        messages: ChatMessage[],
        onContent: (content: string, done: boolean) => void,
        options?: { signal?: AbortSignal },
    ): Promise<void> {
        const { system, userMessages } = splitSystemAndMessages(messages);
        const body: Record<string, unknown> = { model: MODEL, max_tokens: MAX_TOKENS, stream: true, messages: userMessages };
        if (system) body.system = system;
        const response = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "x-api-key": this.apiKey,
                "anthropic-version": "2023-06-01",
                "anthropic-dangerous-direct-browser-access": "true",
            },
            body: JSON.stringify(body),
            signal: options?.signal,
        });
        if (!response.ok) {
            const err = await response.text();
            throw new Error(`Claude API error ${response.status}: ${err}`);
        }
        const reader = response.body!.getReader();
        const decoder = new TextDecoder();
        let accumulated = "";
        try {
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;
                const chunk = decoder.decode(value, { stream: true });
                const lines = chunk.split("\n");
                for (const line of lines) {
                    if (!line.startsWith("data: ")) continue;
                    const data = line.slice(6).trim();
                    if (data === "[DONE]") continue;
                    try {
                        const event = JSON.parse(data);
                        if (event.type === "content_block_delta" && event.delta?.type === "text_delta") {
                            accumulated += event.delta.text;
                            onContent(accumulated, false);
                        }
                    } catch { /* partial SSE line */ }
                }
            }
        } finally {
            reader.releaseLock();
        }
        onContent(accumulated, true);
    }
}
