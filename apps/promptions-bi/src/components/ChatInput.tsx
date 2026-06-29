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
