import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  // Relative base so built assets load correctly when the overlay
  // window opens the HTML via file:// in Electron (absolute "/assets/…"
  // paths fail with ERR_FILE_NOT_FOUND under file://).
  base: "./",
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
  },
  build: {
    target: "chrome120",
    sourcemap: true,
  },
});
