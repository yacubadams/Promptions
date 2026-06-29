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
        borderColor: tokens.colorNeutralStroke1,
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
