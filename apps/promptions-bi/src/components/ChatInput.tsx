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
