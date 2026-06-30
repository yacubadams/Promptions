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
