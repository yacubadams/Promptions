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
