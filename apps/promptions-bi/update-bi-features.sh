#!/bin/bash
# update-bi-features.sh — adds file upload + charts to promptions-bi
set -e
cd ~/Promptions/apps/promptions-bi
echo "Updating BI app with file upload + charts..."

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
    type: "bar" | "line" | "pie" | "area";
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

# ---- src/services/fileParser.ts ----
mkdir -p "$(dirname src/services/fileParser.ts)"
cat > src/services/fileParser.ts << 'PROMPTIONS_EOF'
// fileParser.ts — reads CSV, JSON, and Excel files into text Claude can analyse.
import * as XLSX from "xlsx";

export interface ParsedFile {
    fileName: string;
    // Text representation passed to Claude (CSV-style for tabular data)
    text: string;
    // Approximate row count for the UI chip
    rowCount: number;
}

export async function parseFile(file: File): Promise<ParsedFile> {
    const name = file.name.toLowerCase();

    if (name.endsWith(".csv")) {
        const text = await file.text();
        return { fileName: file.name, text, rowCount: countRows(text) };
    }

    if (name.endsWith(".json")) {
        const raw = await file.text();
        // Pretty-print so Claude sees clean structure; fall back to raw on parse error
        try {
            const parsed = JSON.parse(raw);
            const text = JSON.stringify(parsed, null, 2);
            const rowCount = Array.isArray(parsed) ? parsed.length : 1;
            return { fileName: file.name, text, rowCount };
        } catch {
            return { fileName: file.name, text: raw, rowCount: countRows(raw) };
        }
    }

    if (name.endsWith(".xlsx") || name.endsWith(".xls")) {
        const buffer = await file.arrayBuffer();
        const workbook = XLSX.read(buffer, { type: "array" });
        // Use the first sheet
        const firstSheetName = workbook.SheetNames[0];
        const sheet = workbook.Sheets[firstSheetName];
        const csv = XLSX.utils.sheet_to_csv(sheet);
        return { fileName: file.name, text: csv, rowCount: countRows(csv) };
    }

    // Unknown type — read as plain text
    const text = await file.text();
    return { fileName: file.name, text, rowCount: countRows(text) };
}

function countRows(text: string): number {
    const lines = text.split("\n").filter((l) => l.trim().length > 0);
    // Subtract 1 for header row if there appears to be one
    return Math.max(0, lines.length - 1);
}
PROMPTIONS_EOF

# ---- src/services/chartParser.ts ----
mkdir -p "$(dirname src/services/chartParser.ts)"
cat > src/services/chartParser.ts << 'PROMPTIONS_EOF'
// chartParser.ts — extracts a chart spec from Claude's response.
// Claude is instructed to emit charts inside a fenced block:
//   ```chart
//   { "type": "bar", "xKey": "month", "yKeys": ["revenue"], "data": [...] }
//   ```
import { ChartSpec } from "../types/bi";

const CHART_BLOCK = /```chart\s*([\s\S]*?)```/;

export interface ChartExtraction {
    // The response text with the chart block removed
    cleanedText: string;
    // The parsed chart, if a valid one was found
    chart?: ChartSpec;
}

export function extractChart(text: string): ChartExtraction {
    const match = text.match(CHART_BLOCK);
    if (!match) return { cleanedText: text };

    const jsonStr = match[1].trim();
    let chart: ChartSpec | undefined;
    try {
        const parsed = JSON.parse(jsonStr) as ChartSpec;
        if (isValidChart(parsed)) {
            chart = parsed;
        }
    } catch {
        // Invalid or incomplete JSON (e.g. still streaming) — ignore for now
    }

    // Remove the chart block from the visible text regardless
    const cleanedText = text.replace(CHART_BLOCK, "").trim();
    return { cleanedText, chart };
}

function isValidChart(c: unknown): c is ChartSpec {
    if (typeof c !== "object" || c === null) return false;
    const obj = c as Record<string, unknown>;
    return (
        typeof obj.type === "string" &&
        typeof obj.xKey === "string" &&
        Array.isArray(obj.yKeys) &&
        Array.isArray(obj.data) &&
        obj.data.length > 0
    );
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

When the user pastes raw data (CSV, JSON, or table), analyse it directly — do not ask for clarification before providing initial findings. Always ground your conclusions in the data provided. If you make inferences beyond the data, label them clearly as assumptions.

CHARTS: When a visualisation would help illustrate your answer AND you have concrete numeric data to plot, include exactly one chart by emitting a fenced code block tagged "chart" containing valid JSON with this shape:
\`\`\`chart
{ "type": "bar" | "line" | "pie" | "area", "title": "Short title", "xKey": "columnNameForXAxis", "yKeys": ["numericColumn1", "numericColumn2"], "data": [ { "columnNameForXAxis": "Jan", "numericColumn1": 100 } ] }
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

# ---- src/components/ChatInput.tsx ----
mkdir -p "$(dirname src/components/ChatInput.tsx)"
cat > src/components/ChatInput.tsx << 'PROMPTIONS_EOF'
import React from "react";
import { makeStyles, tokens, Button, Textarea, Spinner } from "@fluentui/react-components";
import { Send24Regular, Table24Regular, Dismiss24Regular, ArrowUpload24Regular } from "@fluentui/react-icons";
import { parseFile } from "../services/fileParser";

const useStyles = makeStyles({
    root: { display: "flex", flexDirection: "column", gap: tokens.spacingVerticalXS, width: "100%" },
    row: { display: "flex", gap: tokens.spacingHorizontalS, alignItems: "flex-end" },
    questionArea: { flex: 1, resize: "none" },
    dataArea: { resize: "vertical", fontFamily: "monospace", fontSize: tokens.fontSizeBase200 },
    dataHeader: { display: "flex", justifyContent: "space-between", alignItems: "center" },
    fileChip: {
        display: "flex", alignItems: "center", gap: tokens.spacingHorizontalXS,
        backgroundColor: tokens.colorBrandBackground2, color: tokens.colorBrandForeground2,
        borderRadius: tokens.borderRadiusMedium,
        padding: `${tokens.spacingVerticalXS} ${tokens.spacingHorizontalS}`,
        fontSize: tokens.fontSizeBase200, alignSelf: "flex-start",
    },
    chipRemove: { background: "none", border: "none", cursor: "pointer", color: tokens.colorBrandForeground2, padding: 0, lineHeight: 1, display: "flex" },
});

interface Props {
    onSend: (question: string, data: string | undefined, fileName: string | undefined) => void;
    disabled: boolean;
}

export const ChatInput: React.FC<Props> = ({ onSend, disabled }) => {
    const styles = useStyles();
    const [question, setQuestion] = React.useState("");
    const [dataExpanded, setDataExpanded] = React.useState(false);
    const [dataText, setDataText] = React.useState("");
    const [fileName, setFileName] = React.useState<string | undefined>(undefined);
    const [fileRows, setFileRows] = React.useState<number>(0);
    const [parsing, setParsing] = React.useState(false);
    const fileInputRef = React.useRef<HTMLInputElement>(null);

    const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        setParsing(true);
        try {
            const parsed = await parseFile(file);
            setDataText(parsed.text);
            setFileName(parsed.fileName);
            setFileRows(parsed.rowCount);
            setDataExpanded(false);
        } catch (err) {
            console.error("File parse error:", err);
            alert("Could not read that file. Try CSV, Excel (.xlsx), or JSON.");
        } finally {
            setParsing(false);
            // reset input so the same file can be re-selected
            if (fileInputRef.current) fileInputRef.current.value = "";
        }
    };

    const clearFile = () => {
        setFileName(undefined);
        setFileRows(0);
        setDataText("");
    };

    const send = () => {
        const q = question.trim();
        if (!q) return;
        onSend(q, dataText.trim() || undefined, fileName);
        setQuestion("");
        setDataText("");
        setFileName(undefined);
        setFileRows(0);
        setDataExpanded(false);
    };

    return (
        <div className={styles.root}>
            {/* Hidden native file input */}
            <input
                ref={fileInputRef}
                type="file"
                accept=".csv,.xlsx,.xls,.json"
                style={{ display: "none" }}
                onChange={handleFile}
            />

            {/* Uploaded file chip */}
            {fileName && (
                <div className={styles.fileChip}>
                    📎 {fileName} ({fileRows} rows)
                    <button className={styles.chipRemove} onClick={clearFile} aria-label="Remove file">
                        <Dismiss24Regular fontSize={16} />
                    </button>
                </div>
            )}

            {/* Optional manual paste area */}
            {dataExpanded && !fileName && (
                <div>
                    <div className={styles.dataHeader}>
                        <span style={{ fontSize: tokens.fontSizeBase200, color: tokens.colorNeutralForeground3 }}>Paste CSV / JSON / table data</span>
                        <Button icon={<Dismiss24Regular />} appearance="subtle" size="small" onClick={() => { setDataExpanded(false); setDataText(""); }} />
                    </div>
                    <Textarea className={styles.dataArea} placeholder={"date,revenue,region\n2024-01-01,42000,North\n…"} value={dataText} onChange={(_, d) => setDataText(d.value)} rows={6} style={{ width: "100%" }} />
                </div>
            )}

            {/* Input row */}
            <div className={styles.row}>
                <Button
                    icon={parsing ? <Spinner size="extra-tiny" /> : <ArrowUpload24Regular />}
                    appearance="subtle"
                    onClick={() => fileInputRef.current?.click()}
                    title="Upload CSV, Excel, or JSON"
                    disabled={parsing}
                />
                <Button
                    icon={<Table24Regular />}
                    appearance="subtle"
                    onClick={() => setDataExpanded((v) => !v)}
                    title="Paste data"
                    style={{ color: dataExpanded ? tokens.colorBrandForeground1 : undefined }}
                />
                <Textarea
                    className={styles.questionArea}
                    placeholder="Ask a business question… (⌘Enter to send)"
                    value={question}
                    onChange={(_, d) => setQuestion(d.value)}
                    onKeyDown={(e) => { if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); send(); } }}
                    disabled={disabled}
                    rows={2}
                    resize="vertical"
                />
                <Button icon={<Send24Regular />} appearance="primary" onClick={send} disabled={disabled || !question.trim()} title="Send" />
            </div>
        </div>
    );
};
PROMPTIONS_EOF

# ---- src/components/MessageBubble.tsx ----
mkdir -p "$(dirname src/components/MessageBubble.tsx)"
cat > src/components/MessageBubble.tsx << 'PROMPTIONS_EOF'
import React from "react";
import { makeStyles, tokens, Badge, Tooltip } from "@fluentui/react-components";
import { BITurn } from "../types/bi";
import { ChartView } from "./ChartView";
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
                    {turn.fileName && <div className={styles.dataAttachment}>📎 {turn.fileName}</div>}
                    {!turn.fileName && turn.dataAttachment && <div className={styles.dataAttachment}>📎 Data attached ({turn.dataAttachment.split("\n").length} rows)</div>}
                </div>
            </div>
        );
    }
    const c = turn.controls;
    return (
        <div className={styles.root}>
            <div className={styles.assistantBubble}>
                <ReactMarkdown remarkPlugins={[remarkGfm]}>{turn.content}</ReactMarkdown>
                {turn.chart && <ChartView chart={turn.chart} />}
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
PROMPTIONS_EOF

# ---- src/App.tsx ----
mkdir -p "$(dirname src/App.tsx)"
cat > src/App.tsx << 'PROMPTIONS_EOF'
import React from "react";
import { FluentProvider, webLightTheme, makeStyles, tokens, Text, Spinner } from "@fluentui/react-components";
import { DataArea24Regular } from "@fluentui/react-icons";
import { produce } from "immer";
import { ClaudeService } from "./services/ClaudeService";
import { BIService } from "./services/BIService";
import { extractChart } from "./services/chartParser";
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

    const handleSend = async (question: string, data: string | undefined, fileName: string | undefined) => {
        abortRef.current?.abort();
        const abort = new AbortController();
        abortRef.current = abort;
        const snapshotControls = { ...controls };
        const userTurn: BITurn = { id: crypto.randomUUID(), role: "user", content: question, dataAttachment: data, fileName };
        const assistantTurn: BITurn = { id: crypto.randomUUID(), role: "assistant", content: "", controls: snapshotControls };
        setTurns((prev) => [...prev, userTurn, assistantTurn]);
        setStreaming(true);
        try {
            await biService.streamAnalysis(question, data, turns, snapshotControls,
                (text, done) => {
                    // While streaming, show raw text. On completion, extract any chart block.
                    if (done) {
                        const { cleanedText, chart } = extractChart(text);
                        setTurns((prev) => produce(prev, (draft) => {
                            const last = draft.at(-1);
                            if (last?.role === "assistant") { last.content = cleanedText; last.chart = chart; }
                        }));
                        setStreaming(false);
                    } else {
                        setTurns((prev) => produce(prev, (draft) => { const last = draft.at(-1); if (last?.role === "assistant") last.content = text; }));
                    }
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
PROMPTIONS_EOF

# ---- tsconfig.json ----
mkdir -p "$(dirname tsconfig.json)"
cat > tsconfig.json << 'PROMPTIONS_EOF'
{
    "compilerOptions": {
        "target": "ES2022",
        "useDefineForClassFields": true,
        "lib": ["ES2022", "DOM", "DOM.Iterable"],
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
PROMPTIONS_EOF

# ---- add recharts + xlsx to package.json ----
node -e "const fs=require('fs');const p='package.json';const d=JSON.parse(fs.readFileSync(p));d.dependencies.recharts='^2.15.0';d.dependencies.xlsx='^0.18.5';fs.writeFileSync(p, JSON.stringify(d,null,4)+String.fromCharCode(10));console.log('package.json updated');"

echo "Files updated. Installing new libraries..."
cd ~/Promptions && yarn install
echo "Done. Verify with: cd apps/promptions-bi && yarn build"
