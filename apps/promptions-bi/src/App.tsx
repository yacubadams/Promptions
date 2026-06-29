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
