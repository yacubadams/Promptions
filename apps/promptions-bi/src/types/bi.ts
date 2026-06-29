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
