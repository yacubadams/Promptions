import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
    plugins: [react()],
    server: {
        port: 3005,
        proxy: {
            "/api/anthropic": {
                target: "https://api.anthropic.com",
                changeOrigin: true,
                rewrite: (path) => path.replace(/^\/api\/anthropic/, ""),
            },
        },
    },
    define: {
        "process.env": {},
    },
});
