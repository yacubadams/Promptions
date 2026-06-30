#!/bin/bash
# add-scatter.sh — adds scatter chart support + makes chart type control authoritative
set -e
cd ~/Promptions/apps/promptions-bi
echo "Adding scatter chart support..."

# ---- src/types/bi.ts ----
mkdir -p "$(dirname src/types/bi.ts)"
cat > src/types/bi.ts << 'PROMPTIONS_EOF'
export type OutputFormat = "narrative" | "table" | "bullet_points" | "executive_summary";
export type Verbosity = "concise" | "standard" | "detailed";
export type TimeGrain = "daily" | "weekly" | "monthly" | "quarterly" | "yearly" | "auto";
export type ChartType = "bar" | "line" | "pie" | "scatter" | "auto";
export type Audience = "analyst" | "executive" | "mixed";
export type ConfidenceDisplay = "none" | "qualitative" | "quantitative";

export interface BIControls {
    outputFormat: OutputFormat;
    verbosity: Verbosity;
    timeGrain: TimeGrain;
    chartType: ChartType;
    audience: Audience;
    confidenceDisplay: ConfidenceDisplay;
    breakdownDimensions: string[];
}

export const DEFAULT_BI_CONTROLS: BIControls = {
    outputFormat: "narrative",
    verbosity: "standard",
    timeGrain: "auto",
    chartType: "auto",
    audience: "analyst",
    confidenceDisplay: "qualitative",
    breakdownDimensions: [],
};

// A chart specification emitted by Claude and rendered by the app
export interface ChartSpec {
    type: "bar" | "line" | "pie" | "area" | "scatter";
    title?: string;
    // The key in each data row used for the x-axis / category labels
    xKey: string;
    // One or more numeric keys to plot as series
    yKeys: string[];
    // The actual rows of data
    data: Record<string, string | number>[];
}

export interface BITurn {
    id: string;
    role: "user" | "assistant";
    content: string;
    controls?: BIControls;
    dataAttachment?: string;
    // Name of the uploaded file, if any
    fileName?: string;
    // Chart parsed out of the assistant's response, if any
    chart?: ChartSpec;
}

export interface BISession {
    turns: BITurn[];
    controls: BIControls;
    streaming: boolean;
}
PROMPTIONS_EOF

# ---- src/services/BIService.ts ----
mkdir -p "$(dirname src/services/BIService.ts)"
cat > src/services/BIService.ts << 'PROMPTIONS_EOF'
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
            ? `The user has explicitly selected the ${controls.chartType} chart type. When you include a chart, you MUST set "type" to "${controls.chartType}". Do not substitute a different type even if another would fit better.`
            : "Choose whichever chart type best suits the data pattern.";
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

When the user pastes raw data (CSV, JSON, or table), analyse it directly — do not ask for clarification before providing initial findings. Always ground your conclusions in the data provided. If you make inferences beyond the data, label them clearly as assumptions.

CHARTS: When a visualisation would help illustrate your answer AND you have concrete numeric data to plot, include exactly one chart by emitting a fenced code block tagged "chart" containing valid JSON with this shape:
\`\`\`chart
{ "type": "bar" | "line" | "pie" | "area" | "scatter", "title": "Short title", "xKey": "columnNameForXAxis", "yKeys": ["numericColumn1", "numericColumn2"], "data": [ { "columnNameForXAxis": "Jan", "numericColumn1": 100 } ] }
\`\`\`
Rules for charts:
- Only include a chart when you have actual numbers from the data to plot. Never invent data.
- The "data" array must use the exact key names given in xKey and yKeys.
- Keep data to at most 30 points.
- Respect the user's chart type preference if one was specified in the CHART GUIDANCE above.
- Place the chart block after your written analysis. Still write your normal text answer.`.trim();
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
PROMPTIONS_EOF

# ---- src/components/ChartView.tsx ----
mkdir -p "$(dirname src/components/ChartView.tsx)"
cat > src/components/ChartView.tsx << 'PROMPTIONS_EOF'
// components/ChartView.tsx — renders a ChartSpec using Recharts.
import React from "react";
import { tokens } from "@fluentui/react-components";
import {
    BarChart, Bar, LineChart, Line, AreaChart, Area,
    PieChart, Pie, Cell,
    ScatterChart, Scatter,
    XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer,
} from "recharts";
import { ChartSpec } from "../types/bi";

const COLORS = ["#4f8ef7", "#2dd4a0", "#f7a34f", "#9d7cf4", "#f75f5f", "#36c5d4"];

interface Props {
    chart: ChartSpec;
}

export const ChartView: React.FC<Props> = ({ chart }) => {
    const { type, title, xKey, yKeys, data } = chart;

    return (
        <div
            style={{
                marginTop: tokens.spacingVerticalM,
                padding: tokens.spacingHorizontalM,
                border: `1px solid ${tokens.colorNeutralStroke2}`,
                borderRadius: tokens.borderRadiusLarge,
                backgroundColor: tokens.colorNeutralBackground1,
            }}
        >
            {title && (
                <div
                    style={{
                        fontSize: tokens.fontSizeBase300,
                        fontWeight: tokens.fontWeightSemibold,
                        marginBottom: tokens.spacingVerticalS,
                    }}
                >
                    {title}
                </div>
            )}
            <ResponsiveContainer width="100%" height={300}>
                {renderChart(type, xKey, yKeys, data)}
            </ResponsiveContainer>
        </div>
    );
};

function renderChart(
    type: ChartSpec["type"],
    xKey: string,
    yKeys: string[],
    data: Record<string, string | number>[],
): React.ReactElement {
    if (type === "line") {
        return (
            <LineChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey={xKey} />
                <YAxis />
                <Tooltip />
                <Legend />
                {yKeys.map((key, i) => (
                    <Line key={key} type="monotone" dataKey={key} stroke={COLORS[i % COLORS.length]} strokeWidth={2} />
                ))}
            </LineChart>
        );
    }

    if (type === "area") {
        return (
            <AreaChart data={data}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey={xKey} />
                <YAxis />
                <Tooltip />
                <Legend />
                {yKeys.map((key, i) => (
                    <Area key={key} type="monotone" dataKey={key} stroke={COLORS[i % COLORS.length]} fill={COLORS[i % COLORS.length]} fillOpacity={0.3} />
                ))}
            </AreaChart>
        );
    }

    if (type === "pie") {
        const pieKey = yKeys[0];
        return (
            <PieChart>
                <Tooltip />
                <Legend />
                <Pie data={data} dataKey={pieKey} nameKey={xKey} cx="50%" cy="50%" outerRadius={100} label>
                    {data.map((_, i) => (
                        <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                </Pie>
            </PieChart>
        );
    }

    if (type === "scatter") {
        return (
            <ScatterChart>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey={xKey} name={xKey} />
                <YAxis dataKey={yKeys[0]} name={yKeys[0]} />
                <Tooltip cursor={{ strokeDasharray: "3 3" }} />
                <Legend />
                {yKeys.map((key, i) => (
                    <Scatter key={key} name={key} data={data} fill={COLORS[i % COLORS.length]} />
                ))}
            </ScatterChart>
        );
    }

    // default: bar
    return (
        <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey={xKey} />
            <YAxis />
            <Tooltip />
            <Legend />
            {yKeys.map((key, i) => (
                <Bar key={key} dataKey={key} fill={COLORS[i % COLORS.length]} />
            ))}
        </BarChart>
    );
}
PROMPTIONS_EOF

echo "Done. Verify with: yarn build"
