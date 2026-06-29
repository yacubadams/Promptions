#!/bin/bash
# setup-promptions-bi.sh
# Run this from inside ~/Promptions/apps/promptions-bi
# It creates every file needed for the BI Assistant app.

set -e
echo "🚀 Setting up promptions-bi..."

# ── package.json ─────────────────────────────────────────────────────────────
cat > package.json << 'HEREDOC'
{
    "name": "@promptions/promptions-bi",
    "version": "1.0.0",
    "type": "module",
    "description": "BI analytics assistant with ephemeral Promptions controls — powered by Claude",
    "license": "MIT",
    "scripts": {
        "dev": "vite --port 3005",
        "build": "tsc && vite build",
        "preview": "vite preview",
        "typecheck": "tsc --noEmit",
        "clean": "rimraf dist",
        "proxy": "node server/proxy.mjs"
    },
    "dependencies": {
        "@fluentui/react-components": "^9.54.0",
        "@fluentui/react-icons": "^2.0.258",
        "immer": "^10.1.1",
        "react": "^18.3.1",
        "react-dom": "^18.3.1",
        "react-markdown": "^10.1.0",
        "rehype-highlight": "^7.0.2",
        "remark-gfm": "^4.0.1"
    },
    "devDependencies": {
        "@types/react": "^18.3.12",
        "@types/react-dom": "^18.3.1",
        "@vitejs/plugin-react": "^4.3.3",
        "rimraf": "^5.0.0",
        "typescript": "^5.6.3",
        "vite": "^7.3.2"
    }
}
HEREDOC

# ── vite.config.ts ────────────────────────────────────────────────────────────
cat > vite.config.ts << 'HEREDOC'
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
    plugins: [react()],
    server: {
        port: 3005,
    },
    define: {
        "process.env": {},
    },
});
HEREDOC

# ── tsconfig.json ─────────────────────────────────────────────────────────────
cat > tsconfig.json << 'HEREDOC'
{
    "compilerOptions": {
        "target": "ES2020",
        "useDefineForClassFields": true,
        "lib": ["ES2020", "DOM", "DOM.Iterable"],
        "module": "ESNext",
        "skipLibCheck": true,
        "moduleResolution": "bundler",
        "allowImportingTsExtensions": true,
        "resolveJsonModule": true,
        "isolatedModules": true,
        "noEmit": true,
        "jsx": "react-jsx",
        "strict": true,
        "noUnusedLocals": true,
        "noUnusedParameters": true,
        "noFallthroughCasesInSwitch": true
    },
    "include": ["src"],
    "references": [{ "path": "./tsconfig.node.json" }]
}
HEREDOC

# ── tsconfig.node.json ────────────────────────────────────────────────────────
cat > tsconfig.node.json << 'HEREDOC'
{
    "compilerOptions": {
        "composite": true,
        "skipLibCheck": true,
        "module": "ESNext",
        "moduleResolution": "bundler",
        "allowSyntheticDefaultImports": true
    },
    "include": ["vite.config.ts"]
}
HEREDOC

# ── index.html ────────────────────────────────────────────────────────────────
cat > index.html << 'HEREDOC'
<!doctype html>
<html lang="en">
    <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>BI Assistant · Promptions</title>
    </head>
    <body>
        <div id="root"></div>
        <script type="module" src="/src/main.tsx"></script>
    </body>
</html>
HEREDOC

# ── .env.example ──────────────────────────────────────────────────────────────
cat > .env.example << 'HEREDOC'
# Auth mode A — direct browser (dev only, key visible in network tab)
VITE_ANTHROPIC_API_KEY=sk-ant-...

# Auth mode B — proxy server (recommended for production)
# Run: ANTHROPIC_API_KEY=sk-ant-... node server/proxy.mjs
# VITE_PROXY_URL=http://localhost:3006
HEREDOC

# ── project.json ──────────────────────────────────────────────────────────────
cat > project.json << 'HEREDOC'
{
    "name": "promptions-bi",
    "targets": {
        "dev": {
            "executor": "nx:run-commands",
            "options": {
                "command": "vite --port 3005",
                "cwd": "{projectRoot}"
            }
        },
        "build": {
            "executor": "nx:run-commands",
            "options": {
                "command": "tsc && vite build",
                "cwd": "{projectRoot}"
            }
        },
        "typecheck": {
            "executor": "nx:run-commands",
            "options": {
                "command": "tsc --noEmit",
                "cwd": "{projectRoot}"
            }
        }
    }
}
HEREDOC

# ── src directories ───────────────────────────────────────────────────────────
mkdir -p src/components src/services src/types server

# ── src/vite-env.d.ts ─────────────────────────────────────────────────────────
cat > src/vite-env.d.ts << 'HEREDOC'
/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_ANTHROPIC_API_KEY?: string;
    readonly VITE_PROXY_URL?: string;
}

interface ImportMeta {
    readonly env: ImportMetaEnv;
}
HEREDOC

# ── src/index.css ─────────────────────────────────────────────────────────────
cat > src/index.css << 'HEREDOC'
*,
*::before,
*::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

html, body, #root {
    height: 100%;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

@keyframes blink {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0; }
}

table {
    border-collapse: collapse;
    width: 100%;
    margin: 0.75em 0;
    font-size: 0.875em;
}
th, td {
    border: 1px solid #d1d5db;
    padding: 6px 12px;
    text-align: left;
}
th { background: #f3f4f6; font-weight: 600; }
tr:nth-child(even) td { background: #f9fafb; }

pre {
    background: #1e1e1e;
    color: #d4d4d4;
    padding: 1em;
    border-radius: 6px;
    overflow-x: auto;
    font-size: 0.85em;
    margin: 0.75em 0;
}
code { font-family: "Cascadia Code", "Fira Code", "Consolas", monospace; }
p { line-height: 1.6; margin-bottom: 0.5em; }
ul, ol { padding-left: 1.4em; margin-bottom: 0.5em; }
li { margin-bottom: 0.25em; }
h1, h2, h3 { margin: 0.6em 0 0.3em; }
HEREDOC

# ── src/types/bi.ts ───────────────────────────────────────────────────────────
cat > src/types/bi.ts << 'HEREDOC'
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

export interface BITurn {
    id: string;
    role: "user" | "assistant";
    content: string;
    controls?: BIControls;
    dataAttachment?: string;
}

export interface BISession {
    turns: BITurn[];
    controls: BIControls;
    streaming: boolean;
}
HEREDOC

# ── src/services/ClaudeService.ts ─────────────────────────────────────────────
cat > src/services/ClaudeService.ts << 'HEREDOC'
export interface ChatMessage {
    role: "user" | "assistant" | "system";
    content: string;
}

const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 4000;

function getEndpointAndHeaders(): { url: string; headers: Record<string, string> } {
    const proxyUrl = import.meta.env.VITE_PROXY_URL;
    if (proxyUrl) {
        return {
            url: `${proxyUrl}/v1/messages`,
            headers: { "Content-Type": "application/json" },
        };
    }
    const apiKey = import.meta.env.VITE_ANTHROPIC_API_KEY;
    if (!apiKey) {
        throw new Error(
            "No API key configured. Set VITE_ANTHROPIC_API_KEY in your .env file.",
        );
    }
    return {
        url: "https://api.anthropic.com/v1/messages",
        headers: {
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "anthropic-dangerous-request-origin": "true",
        },
    };
}

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
    async sendMessage(messages: ChatMessage[]): Promise<string> {
        const { url, headers } = getEndpointAndHeaders();
        const { system, userMessages } = splitSystemAndMessages(messages);
        const body: Record<string, unknown> = {
            model: MODEL,
            max_tokens: MAX_TOKENS,
            messages: userMessages,
        };
        if (system) body.system = system;
        const response = await fetch(url, {
            method: "POST",
            headers,
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
        const { url, headers } = getEndpointAndHeaders();
        const { system, userMessages } = splitSystemAndMessages(messages);
        const body: Record<string, unknown> = {
            model: MODEL,
            max_tokens: MAX_TOKENS,
            stream: true,
            messages: userMessages,
        };
        if (system) body.system = system;
        const response = await fetch(url, {
            method: "POST",
            headers,
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
HEREDOC

# ── src/services/BIService.ts ─────────────────────────────────────────────────
cat > src/services/BIService.ts << 'HEREDOC'
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
HEREDOC

# ── src/components/ControlsPanel.tsx ─────────────────────────────────────────
cat > src/components/ControlsPanel.tsx << 'HEREDOC'
import React from "react";
import {
    makeStyles, tokens, Button, Divider, Text, Badge,
} from "@fluentui/react-components";
import {
    Settings24Regular, ChevronLeft24Regular, ChevronRight24Regular, Sparkle24Regular,
} from "@fluentui/react-icons";
import {
    BIControls, OutputFormat, Verbosity, TimeGrain, ChartType, Audience, ConfidenceDisplay,
} from "../types/bi";

const useStyles = makeStyles({
    panel: {
        width: "280px", minWidth: "280px",
        borderRight: `1px solid ${tokens.colorNeutralStroke2}`,
        backgroundColor: tokens.colorNeutralBackground2,
        display: "flex", flexDirection: "column", overflowY: "auto",
        transition: "width 0.2s ease, min-width 0.2s ease",
    },
    panelCollapsed: { width: "48px", minWidth: "48px" },
    header: {
        display: "flex", alignItems: "center", justifyContent: "space-between",
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalM}`,
        borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
    },
    headerTitle: { display: "flex", alignItems: "center", gap: tokens.spacingHorizontalS },
    section: { padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}` },
    sectionLabel: {
        fontSize: tokens.fontSizeBase200, fontWeight: tokens.fontWeightSemibold,
        color: tokens.colorNeutralForeground3, textTransform: "uppercase",
        letterSpacing: "0.05em", marginBottom: tokens.spacingVerticalXS, display: "block",
    },
    chipGroup: { display: "flex", flexWrap: "wrap", gap: tokens.spacingHorizontalXS, marginBottom: tokens.spacingVerticalS },
    chip: {
        cursor: "pointer", border: `1px solid ${tokens.colorNeutralStroke1}`,
        borderRadius: tokens.borderRadiusMedium,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        fontSize: tokens.fontSizeBase200, backgroundColor: tokens.colorNeutralBackground1,
        color: tokens.colorNeutralForeground1, transition: "all 0.1s",
    },
    chipActive: {
        backgroundColor: tokens.colorBrandBackground,
        color: tokens.colorNeutralForegroundOnBrand,
        borderColor: tokens.colorBrandBackground,
    },
    dimensionInput: { display: "flex", gap: tokens.spacingHorizontalXS, marginBottom: tokens.spacingVerticalXS },
    removeBtn: { background: "none", border: "none", cursor: "pointer", color: tokens.colorBrandForeground2, padding: "0 2px", lineHeight: 1 },
    suggestButton: { margin: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalM}` },
    dimInput: {
        flex: 1, border: `1px solid ${tokens.colorNeutralStroke1}`,
        borderRadius: tokens.borderRadiusMedium,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        fontSize: tokens.fontSizeBase200, outline: "none",
    },
});

interface Props {
    controls: BIControls;
    onChange: (patch: Partial<BIControls>) => void;
    onSuggest: () => void;
    suggesting: boolean;
    collapsed: boolean;
    onToggle: () => void;
}

function ChipSelector<T extends string>({ value, options, onChange, styles }: {
    value: T; options: { value: T; label: string }[];
    onChange: (v: T) => void; styles: ReturnType<typeof useStyles>;
}) {
    return (
        <div className={styles.chipGroup}>
            {options.map((opt) => (
                <div key={opt.value}
                    className={`${styles.chip} ${value === opt.value ? styles.chipActive : ""}`}
                    onClick={() => onChange(opt.value)}
                    role="button" aria-pressed={value === opt.value}>
                    {opt.label}
                </div>
            ))}
        </div>
    );
}

export const ControlsPanel: React.FC<Props> = ({ controls, onChange, onSuggest, suggesting, collapsed, onToggle }) => {
    const styles = useStyles();
    const [dimInput, setDimInput] = React.useState("");

    const addDimension = () => {
        const trimmed = dimInput.trim();
        if (!trimmed || controls.breakdownDimensions.includes(trimmed)) return;
        onChange({ breakdownDimensions: [...controls.breakdownDimensions, trimmed] });
        setDimInput("");
    };

    if (collapsed) {
        return (
            <div className={`${styles.panel} ${styles.panelCollapsed}`}>
                <div className={styles.header} style={{ justifyContent: "center" }}>
                    <Button icon={<ChevronRight24Regular />} appearance="subtle" onClick={onToggle} title="Expand controls" />
                </div>
            </div>
        );
    }

    return (
        <div className={styles.panel}>
            <div className={styles.header}>
                <div className={styles.headerTitle}>
                    <Settings24Regular style={{ color: tokens.colorBrandForeground1 }} />
                    <Text weight="semibold">Controls</Text>
                </div>
                <Button icon={<ChevronLeft24Regular />} appearance="subtle" onClick={onToggle} title="Collapse" />
            </div>
            <div className={styles.suggestButton}>
                <Button icon={<Sparkle24Regular />} appearance="primary" onClick={onSuggest} disabled={suggesting} style={{ width: "100%" }}>
                    {suggesting ? "Suggesting…" : "Auto-tune controls"}
                </Button>
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Audience</span>
                <ChipSelector<Audience> value={controls.audience} onChange={(v) => onChange({ audience: v })}
                    options={[{ value: "analyst", label: "Analyst" }, { value: "executive", label: "Executive" }, { value: "mixed", label: "Mixed" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Output format</span>
                <ChipSelector<OutputFormat> value={controls.outputFormat} onChange={(v) => onChange({ outputFormat: v })}
                    options={[{ value: "narrative", label: "Narrative" }, { value: "table", label: "Table" }, { value: "bullet_points", label: "Bullets" }, { value: "executive_summary", label: "Exec summary" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Verbosity</span>
                <ChipSelector<Verbosity> value={controls.verbosity} onChange={(v) => onChange({ verbosity: v })}
                    options={[{ value: "concise", label: "Concise" }, { value: "standard", label: "Standard" }, { value: "detailed", label: "Detailed" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Time grain</span>
                <ChipSelector<TimeGrain> value={controls.timeGrain} onChange={(v) => onChange({ timeGrain: v })}
                    options={[{ value: "auto", label: "Auto" }, { value: "daily", label: "Daily" }, { value: "weekly", label: "Weekly" }, { value: "monthly", label: "Monthly" }, { value: "quarterly", label: "Quarterly" }, { value: "yearly", label: "Yearly" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Chart type</span>
                <ChipSelector<ChartType> value={controls.chartType} onChange={(v) => onChange({ chartType: v })}
                    options={[{ value: "auto", label: "Auto" }, { value: "bar", label: "Bar" }, { value: "line", label: "Line" }, { value: "pie", label: "Pie" }, { value: "scatter", label: "Scatter" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Confidence display</span>
                <ChipSelector<ConfidenceDisplay> value={controls.confidenceDisplay} onChange={(v) => onChange({ confidenceDisplay: v })}
                    options={[{ value: "none", label: "None" }, { value: "qualitative", label: "Qualitative" }, { value: "quantitative", label: "Quantitative" }]} styles={styles} />
            </div>
            <Divider />
            <div className={styles.section}>
                <span className={styles.sectionLabel}>Breakdown dimensions</span>
                {controls.breakdownDimensions.length > 0 && (
                    <div className={styles.chipGroup}>
                        {controls.breakdownDimensions.map((dim) => (
                            <Badge key={dim} appearance="tint" color="brand" style={{ cursor: "default" }}>
                                {dim}
                                <button className={styles.removeBtn} onClick={() => onChange({ breakdownDimensions: controls.breakdownDimensions.filter((d) => d !== dim) })} aria-label={`Remove ${dim}`}>×</button>
                            </Badge>
                        ))}
                    </div>
                )}
                <div className={styles.dimensionInput}>
                    <input className={styles.dimInput} placeholder="e.g. region, product" value={dimInput}
                        onChange={(e) => setDimInput(e.target.value)}
                        onKeyDown={(e) => { if (e.key === "Enter") addDimension(); }} />
                    <Button size="small" onClick={addDimension}>Add</Button>
                </div>
            </div>
        </div>
    );
};
HEREDOC

# ── src/components/ChatInput.tsx ──────────────────────────────────────────────
cat > src/components/ChatInput.tsx << 'HEREDOC'
import React from "react";
import { makeStyles, tokens, Button, Textarea } from "@fluentui/react-components";
import { Send24Regular, Table24Regular, Dismiss24Regular } from "@fluentui/react-icons";

const useStyles = makeStyles({
    root: { display: "flex", flexDirection: "column", gap: tokens.spacingVerticalXS, width: "100%" },
    row: { display: "flex", gap: tokens.spacingHorizontalS, alignItems: "flex-end" },
    questionArea: { flex: 1, resize: "none" },
    dataArea: { resize: "vertical", fontFamily: "monospace", fontSize: tokens.fontSizeBase200 },
    dataHeader: { display: "flex", justifyContent: "space-between", alignItems: "center" },
});

interface Props {
    onSend: (question: string, data: string | undefined) => void;
    disabled: boolean;
}

export const ChatInput: React.FC<Props> = ({ onSend, disabled }) => {
    const styles = useStyles();
    const [question, setQuestion] = React.useState("");
    const [dataExpanded, setDataExpanded] = React.useState(false);
    const [dataText, setDataText] = React.useState("");

    const send = () => {
        const q = question.trim();
        if (!q) return;
        onSend(q, dataText.trim() || undefined);
        setQuestion(""); setDataText(""); setDataExpanded(false);
    };

    return (
        <div className={styles.root}>
            {dataExpanded && (
                <div>
                    <div className={styles.dataHeader}>
                        <span style={{ fontSize: tokens.fontSizeBase200, color: tokens.colorNeutralForeground3 }}>Paste CSV / JSON / table data</span>
                        <Button icon={<Dismiss24Regular />} appearance="subtle" size="small" onClick={() => { setDataExpanded(false); setDataText(""); }} />
                    </div>
                    <Textarea className={styles.dataArea} placeholder={"date,revenue,region\n2024-01-01,42000,North\n…"} value={dataText} onChange={(_, d) => setDataText(d.value)} rows={6} style={{ width: "100%" }} />
                </div>
            )}
            <div className={styles.row}>
                <Button icon={<Table24Regular />} appearance="subtle" onClick={() => setDataExpanded((v) => !v)} title="Attach data"
                    style={{ color: dataExpanded ? tokens.colorBrandForeground1 : undefined }} />
                <Textarea className={styles.questionArea} placeholder="Ask a business question… (⌘Enter to send)"
                    value={question} onChange={(_, d) => setQuestion(d.value)}
                    onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); send(); } }}
                    disabled={disabled} rows={2} resize="vertical" />
                <Button icon={<Send24Regular />} appearance="primary" onClick={send} disabled={disabled || !question.trim()} title="Send" />
            </div>
        </div>
    );
};
HEREDOC

# ── src/components/MessageBubble.tsx ─────────────────────────────────────────
cat > src/components/MessageBubble.tsx << 'HEREDOC'
import React from "react";
import { makeStyles, tokens, Badge, Tooltip } from "@fluentui/react-components";
import { BITurn } from "../types/bi";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

const useStyles = makeStyles({
    root: { display: "flex", flexDirection: "column", gap: tokens.spacingVerticalXS, marginBottom: tokens.spacingVerticalL },
    userBubble: {
        alignSelf: "flex-end", maxWidth: "70%",
        backgroundColor: tokens.colorBrandBackground2, color: tokens.colorBrandForeground2,
        borderRadius: `${tokens.borderRadiusLarge} ${tokens.borderRadiusLarge} ${tokens.borderRadiusSmall} ${tokens.borderRadiusLarge}`,
        padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalM}`,
        fontSize: tokens.fontSizeBase300, whiteSpace: "pre-wrap",
    },
    assistantBubble: {
        alignSelf: "flex-start", maxWidth: "90%",
        backgroundColor: tokens.colorNeutralBackground1,
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        borderRadius: `${tokens.borderRadiusLarge} ${tokens.borderRadiusLarge} ${tokens.borderRadiusLarge} ${tokens.borderRadiusSmall}`,
        padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalM}`,
    },
    controlsBadgeRow: {
        display: "flex", flexWrap: "wrap", gap: tokens.spacingHorizontalXS,
        marginTop: tokens.spacingVerticalXS, paddingTop: tokens.spacingVerticalXS,
        borderTop: `1px solid ${tokens.colorNeutralStroke3}`,
    },
    dataAttachment: { fontSize: tokens.fontSizeBase200, color: tokens.colorNeutralForeground3, fontStyle: "italic", marginTop: tokens.spacingVerticalXS },
});

interface Props { turn: BITurn; streaming?: boolean; }

export const MessageBubble: React.FC<Props> = ({ turn, streaming }) => {
    const styles = useStyles();
    if (turn.role === "user") {
        return (
            <div className={styles.root}>
                <div className={styles.userBubble}>
                    {turn.content}
                    {turn.dataAttachment && <div className={styles.dataAttachment}>📎 Data attached ({turn.dataAttachment.split("\n").length} rows)</div>}
                </div>
            </div>
        );
    }
    const c = turn.controls;
    return (
        <div className={styles.root}>
            <div className={styles.assistantBubble}>
                <ReactMarkdown remarkPlugins={[remarkGfm]}>{turn.content}</ReactMarkdown>
                {streaming && <span style={{ display: "inline-block", width: 2, height: "1em", backgroundColor: tokens.colorBrandForeground1, marginLeft: 2, animation: "blink 1s step-end infinite" }} />}
                {c && (
                    <div className={styles.controlsBadgeRow}>
                        <Tooltip content={`Audience: ${c.audience}`} relationship="label"><Badge appearance="tint" color="informative" size="small">{c.audience}</Badge></Tooltip>
                        <Tooltip content={`Format: ${c.outputFormat}`} relationship="label"><Badge appearance="tint" color="subtle" size="small">{c.outputFormat.replace("_", " ")}</Badge></Tooltip>
                        <Tooltip content={`Verbosity: ${c.verbosity}`} relationship="label"><Badge appearance="tint" color="subtle" size="small">{c.verbosity}</Badge></Tooltip>
                        {c.timeGrain !== "auto" && <Tooltip content={`Time grain: ${c.timeGrain}`} relationship="label"><Badge appearance="tint" color="warning" size="small">{c.timeGrain}</Badge></Tooltip>}
                        {c.breakdownDimensions.map((dim) => <Badge key={dim} appearance="tint" color="success" size="small">÷ {dim}</Badge>)}
                    </div>
                )}
            </div>
        </div>
    );
};
HEREDOC

# ── src/components/index.ts ───────────────────────────────────────────────────
cat > src/components/index.ts << 'HEREDOC'
export { ControlsPanel } from "./ControlsPanel";
export { ChatInput } from "./ChatInput";
export { MessageBubble } from "./MessageBubble";
HEREDOC

# ── src/App.tsx ───────────────────────────────────────────────────────────────
cat > src/App.tsx << 'HEREDOC'
import React from "react";
import { FluentProvider, webLightTheme, makeStyles, tokens, Text, Spinner } from "@fluentui/react-components";
import { DataArea24Regular } from "@fluentui/react-icons";
import { produce } from "immer";
import { ClaudeService } from "./services/ClaudeService";
import { BIService } from "./services/BIService";
import { ControlsPanel, ChatInput, MessageBubble } from "./components";
import { BIControls, BITurn, DEFAULT_BI_CONTROLS } from "./types/bi";

const useStyles = makeStyles({
    app: { height: "100vh", display: "flex", flexDirection: "row", backgroundColor: tokens.colorNeutralBackground1, overflow: "hidden" },
    main: { flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" },
    topBar: { display: "flex", alignItems: "center", gap: tokens.spacingHorizontalS, padding: `${tokens.spacingVerticalS} ${tokens.spacingHorizontalL}`, borderBottom: `1px solid ${tokens.colorNeutralStroke2}`, backgroundColor: tokens.colorNeutralBackground1 },
    scrollArea: { flex: 1, overflowY: "auto", padding: `${tokens.spacingVerticalL} ${tokens.spacingHorizontalXL}`, display: "flex", flexDirection: "column" },
    messagesInner: { maxWidth: "800px", width: "100%", alignSelf: "center", flex: 1, display: "flex", flexDirection: "column" },
    emptyState: { flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: tokens.spacingVerticalM, color: tokens.colorNeutralForeground3 },
    inputBar: { padding: `${tokens.spacingVerticalM} ${tokens.spacingHorizontalXL}`, borderTop: `1px solid ${tokens.colorNeutralStroke2}`, backgroundColor: tokens.colorNeutralBackground1 },
    inputInner: { maxWidth: "800px", margin: "0 auto" },
});

const claude = new ClaudeService();
const biService = new BIService(claude);

export default function App() {
    const styles = useStyles();
    const [controls, setControls] = React.useState<BIControls>(DEFAULT_BI_CONTROLS);
    const [turns, setTurns] = React.useState<BITurn[]>([]);
    const [streaming, setStreaming] = React.useState(false);
    const [suggesting, setSuggesting] = React.useState(false);
    const [controlsCollapsed, setControlsCollapsed] = React.useState(false);
    const scrollRef = React.useRef<HTMLDivElement>(null);
    const abortRef = React.useRef<AbortController | null>(null);

    React.useEffect(() => {
        if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }, [turns]);

    const handleSuggest = async () => {
        const lastUserTurn = [...turns].reverse().find((t) => t.role === "user");
        if (!lastUserTurn?.content) return;
        setSuggesting(true);
        try {
            const patch = await biService.suggestControls(lastUserTurn.content, controls);
            setControls((prev) => ({ ...prev, ...patch }));
        } catch (e) { console.error("suggestControls error:", e); }
        finally { setSuggesting(false); }
    };

    const handleSend = async (question: string, data: string | undefined) => {
        abortRef.current?.abort();
        const abort = new AbortController();
        abortRef.current = abort;
        const snapshotControls = { ...controls };
        const userTurn: BITurn = { id: crypto.randomUUID(), role: "user", content: question, dataAttachment: data };
        const assistantTurn: BITurn = { id: crypto.randomUUID(), role: "assistant", content: "", controls: snapshotControls };
        setTurns((prev) => [...prev, userTurn, assistantTurn]);
        setStreaming(true);
        try {
            await biService.streamAnalysis(question, data, turns, snapshotControls,
                (text, done) => {
                    setTurns((prev) => produce(prev, (draft) => { const last = draft.at(-1); if (last?.role === "assistant") last.content = text; }));
                    if (done) setStreaming(false);
                }, abort.signal);
        } catch (e: unknown) {
            if (e instanceof Error && e.name === "AbortError") return;
            setTurns((prev) => produce(prev, (draft) => { const last = draft.at(-1); if (last?.role === "assistant") last.content = `⚠️ Error: ${(e as Error).message}`; }));
            setStreaming(false);
        }
    };

    return (
        <FluentProvider theme={webLightTheme}>
            <div className={styles.app}>
                <ControlsPanel controls={controls} onChange={(patch) => setControls((prev) => ({ ...prev, ...patch }))}
                    onSuggest={handleSuggest} suggesting={suggesting}
                    collapsed={controlsCollapsed} onToggle={() => setControlsCollapsed((v) => !v)} />
                <div className={styles.main}>
                    <div className={styles.topBar}>
                        <DataArea24Regular style={{ color: tokens.colorBrandForeground1 }} />
                        <Text size={400} weight="semibold">BI Assistant</Text>
                        {streaming && <Spinner size="extra-tiny" label="Analysing…" labelPosition="after" />}
                    </div>
                    <div className={styles.scrollArea} ref={scrollRef}>
                        <div className={styles.messagesInner}>
                            {turns.length === 0 ? (
                                <div className={styles.emptyState}>
                                    <DataArea24Regular style={{ width: 48, height: 48, opacity: 0.3 }} />
                                    <Text size={400} weight="semibold">Ask a business question</Text>
                                    <Text size={300} style={{ textAlign: "center", maxWidth: 400 }}>
                                        Paste a CSV, describe your data, or ask why a metric moved.<br />
                                        Use the Controls panel to tune format, audience, and detail level.
                                    </Text>
                                </div>
                            ) : (
                                turns.map((turn, i) => <MessageBubble key={turn.id} turn={turn} streaming={streaming && i === turns.length - 1} />)
                            )}
                        </div>
                    </div>
                    <div className={styles.inputBar}>
                        <div className={styles.inputInner}>
                            <ChatInput onSend={handleSend} disabled={streaming} />
                        </div>
                    </div>
                </div>
            </div>
        </FluentProvider>
    );
}
HEREDOC

# ── src/main.tsx ──────────────────────────────────────────────────────────────
cat > src/main.tsx << 'HEREDOC'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
    <React.StrictMode>
        <App />
    </React.StrictMode>,
);
HEREDOC

# ── server/proxy.mjs ──────────────────────────────────────────────────────────
cat > server/proxy.mjs << 'HEREDOC'
#!/usr/bin/env node
import http from "http";
import https from "https";

const PORT = process.env.PROXY_PORT ?? 3006;
const API_KEY = process.env.ANTHROPIC_API_KEY;

if (!API_KEY) { console.error("❌  ANTHROPIC_API_KEY required."); process.exit(1); }

const server = http.createServer((req, res) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    if (req.method === "OPTIONS") { res.writeHead(204); res.end(); return; }
    if (req.method !== "POST" || !req.url?.startsWith("/v1/")) { res.writeHead(404); res.end("Not found"); return; }
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
        const body = Buffer.concat(chunks);
        const proxyReq = https.request({
            hostname: "api.anthropic.com", path: req.url, method: "POST",
            headers: { "Content-Type": "application/json", "Content-Length": body.length, "x-api-key": API_KEY, "anthropic-version": "2023-06-01" },
        }, (proxyRes) => { res.writeHead(proxyRes.statusCode, proxyRes.headers); proxyRes.pipe(res); });
        proxyReq.on("error", (e) => { console.error("Proxy error:", e); res.writeHead(502); res.end("Bad gateway"); });
        proxyReq.write(body); proxyReq.end();
    });
});

server.listen(PORT, () => console.log(`✅  BI Proxy on http://localhost:${PORT}`));
HEREDOC

echo ""
echo "✅  promptions-bi scaffold complete!"
echo ""
echo "Next steps:"
echo "  1. cp .env.example .env"
echo "  2. Add your Anthropic API key to .env"
echo "  3. cd ~/Promptions && yarn install"
echo "  4. cd apps/promptions-bi && yarn dev"
echo ""
