import { ClaudeService, ChatMessage } from "./ClaudeService";
import { BIControls, BITurn } from "../types/bi";

export class BIService {
    constructor(private claude: ClaudeService) {}

    private buildSystemPrompt(controls: BIControls): string {
        const audienceGuidance: Record<BIControls["audience"], string> = {
            analyst: "Assume a technically literate audience comfortable with data, statistics, and BI terminology.",
            executive: "Assume a non-technical executive audience. Lead with business impact. Avoid jargon and raw numbers without context.",
            mixed: "Balance technical depth with plain-English summaries. Provide both a headline finding and supporting detail.",
        };
        const formatGuidance: Record<BIControls["outputFormat"], string> = {
            narrative: "Write your response as flowing prose paragraphs.",
            table: "Wherever possible, structure findings in markdown tables.",
            bullet_points: "Use concise bullet points. Each bullet should express exactly one finding.",
            executive_summary: "Open with a one-sentence headline, then provide 3-5 key bullets, then a brief recommendation.",
        };
        const verbosityGuidance: Record<BIControls["verbosity"], string> = {
            concise: "Keep your total response under 150 words.",
            standard: "Aim for a response between 150 and 400 words.",
            detailed: "Be thorough. Include caveats, methodology notes, and alternative interpretations.",
        };
        const confidenceGuidance: Record<BIControls["confidenceDisplay"], string> = {
            none: "Do not comment on confidence or data quality.",
            qualitative: "At the end of your response, add a one-sentence qualitative confidence note (e.g. 'Confidence: moderate — limited sample size.').",
            quantitative: "At the end of your response, estimate a numeric confidence percentage and explain the main uncertainty drivers.",
        };
        const timeGrainNote = controls.timeGrain !== "auto"
            ? `When analysing time-series data, aggregate to the ${controls.timeGrain} level unless the user asks otherwise.`
            : "Choose the most appropriate time granularity based on the data provided.";
        const chartNote = controls.chartType !== "auto"
            ? `If you suggest a visualisation, recommend a ${controls.chartType} chart.`
            : "Recommend whichever chart type best suits the data pattern.";
        const breakdownNote = controls.breakdownDimensions.length > 0
            ? `The user wants the analysis broken down by: ${controls.breakdownDimensions.join(", ")}. Prioritise these dimensions in your response.`
            : "";

        return `You are an expert business intelligence analyst assistant.

AUDIENCE: ${audienceGuidance[controls.audience]}
OUTPUT FORMAT: ${formatGuidance[controls.outputFormat]}
VERBOSITY: ${verbosityGuidance[controls.verbosity]}
TIME GRAIN: ${timeGrainNote}
CHART GUIDANCE: ${chartNote}
CONFIDENCE: ${confidenceGuidance[controls.confidenceDisplay]}
${breakdownNote}

When the user pastes raw data (CSV, JSON, or table), analyse it directly — do not ask for clarification before providing initial findings. Always ground your conclusions in the data provided. If you make inferences beyond the data, label them clearly as assumptions.`.trim();
    }

    async streamAnalysis(
        question: string,
        dataAttachment: string | undefined,
        history: BITurn[],
        controls: BIControls,
        onContent: (text: string, done: boolean) => void,
        signal?: AbortSignal,
    ): Promise<void> {
        const messages: ChatMessage[] = [
            { role: "system", content: this.buildSystemPrompt(controls) },
            ...history.flatMap((turn): ChatMessage[] => {
                if (turn.role === "user") {
                    const content = turn.dataAttachment
                        ? `${turn.content}\n\n---\n**Data:**\n\`\`\`\n${turn.dataAttachment}\n\`\`\``
                        : turn.content;
                    return [{ role: "user", content }];
                }
                return [{ role: "assistant", content: turn.content }];
            }),
            {
                role: "user",
                content: dataAttachment
                    ? `${question}\n\n---\n**Data:**\n\`\`\`\n${dataAttachment}\n\`\`\``
                    : question,
            },
        ];
        await this.claude.streamChat(messages, onContent, { signal });
    }

    async suggestControls(question: string, currentControls: BIControls): Promise<Partial<BIControls>> {
        const prompt = `A business analyst just asked: "${question}"

Current BI controls: ${JSON.stringify(currentControls, null, 2)}

Suggest updated control values that would produce the best answer for this question.
Respond ONLY with a JSON object containing only the fields you want to change.
Valid field values:
- outputFormat: "narrative" | "table" | "bullet_points" | "executive_summary"
- verbosity: "concise" | "standard" | "detailed"
- timeGrain: "daily" | "weekly" | "monthly" | "quarterly" | "yearly" | "auto"
- chartType: "bar" | "line" | "pie" | "scatter" | "auto"
- audience: "analyst" | "executive" | "mixed"
- confidenceDisplay: "none" | "qualitative" | "quantitative"
- breakdownDimensions: string[]

Return only the JSON object, no markdown fences, no explanation.`;
        const raw = await this.claude.sendMessage([{ role: "user", content: prompt }]);
        try {
            const clean = raw.replace(/\`\`\`json|\`\`\`/g, "").trim();
            return JSON.parse(clean) as Partial<BIControls>;
        } catch {
            return {};
        }
    }
}
