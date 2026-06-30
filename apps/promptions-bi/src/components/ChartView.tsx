// components/ChartView.tsx — renders a ChartSpec using Recharts.
import React from "react";
import { tokens } from "@fluentui/react-components";
import {
    BarChart, Bar, LineChart, Line, AreaChart, Area,
    PieChart, Pie, Cell,
    ScatterChart, Scatter,
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

    if (type === "scatter") {
        return (
            <ScatterChart>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey={xKey} name={xKey} />
                <YAxis dataKey={yKeys[0]} name={yKeys[0]} />
                <Tooltip cursor={{ strokeDasharray: "3 3" }} />
                <Legend />
                {yKeys.map((key, i) => (
                    <Scatter key={key} name={key} data={data} fill={COLORS[i % COLORS.length]} />
                ))}
            </ScatterChart>
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
