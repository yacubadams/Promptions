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
