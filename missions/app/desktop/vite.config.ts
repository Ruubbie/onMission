import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Same build serves the browser preview (npm run dev) and the Tauri Windows app.
export default defineConfig({
  plugins: [react()],
  clearScreen: false,
  server: { port: 5173, strictPort: true },
  build: { target: "es2022" },
});
