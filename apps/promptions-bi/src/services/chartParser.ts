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
