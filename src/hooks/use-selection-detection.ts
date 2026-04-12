/**
 * useSelectionDetection
 *
 * Bridges Electron IPC selection events to the event bus and handles
 * the suggestion flow: detect text → get suggestions → emit ready.
 * Also listens for action-chosen events and routes them to inference.
 */

import { useEffect } from "react";
import { eventBus } from "../events/event-bus";
import { useCursorStore } from "../stores/cursor-store";

export function useSelectionDetection(): void {
  // Listen for selection detected from Electron
  useEffect(() => {
    const api = window.electronAPI;
    if (!api?.onSelectionDetected) return;

    let bubbleTimeout: ReturnType<typeof setTimeout> | null = null;
    const clearBubble = () => {
      if (bubbleTimeout) clearTimeout(bubbleTimeout);
      bubbleTimeout = null;
      eventBus.emit("cursor:set-bubble-text", { text: "" });
    };

    const cleanup = api.onSelectionDetected(async (data: Record<string, unknown>) => {
      const text = data.text as string;
      const source = data.source as string;
      if (!text || text.trim().length === 0) return;

      const bounds = (data.bounds as { x: number; y: number; width: number; height: number } | null) || null;
      const app = (data.app as string | null) || null;
      const preview = text.trim().length > 42 ? text.trim().slice(0, 39) + "…" : text.trim();

      eventBus.emit("selection:text-detected", {
        text,
        source: source as "clipboard" | "accessibility" | "hotkey" | "manual",
        bounds,
        app,
      });

      // If we have selection bounds, fly the cursor to the selection
      eventBus.emit("cursor:show");

      if (bounds) {
        const targetX = bounds.x + bounds.width + 10; // just right of selection
        const targetY = bounds.y + Math.round(bounds.height / 2); // vertically centered
        eventBus.emit("cursor:fly-to", {
          x: targetX,
          y: targetY,
          label: "selection",
          bubbleText: preview,
        });
      } else {
        eventBus.emit("cursor:set-bubble-text", { text: preview });
      }

      if (bubbleTimeout) clearTimeout(bubbleTimeout);
      bubbleTimeout = setTimeout(() => {
        eventBus.emit("cursor:set-bubble-text", { text: "" });
      }, 3500);

      // Request suggestions from main process
      if (api.getSelectionSuggestions) {
        try {
          const suggestions = await api.getSelectionSuggestions(text);
          if (suggestions && suggestions.length > 0) {
            eventBus.emit("selection:suggestions-ready", {
              text,
              suggestions,
            });
          }
        } catch (err) {
          console.warn("[useSelectionDetection] Failed to get suggestions:", err);
        }
      }
    });

    const clearCleanup = api.onSelectionCleared?.(() => {
      eventBus.emit("selection:cleared", {});
      clearBubble();
    });

    return () => {
      clearBubble();
      if (typeof cleanup === "function") cleanup();
      if (typeof clearCleanup === "function") clearCleanup();
    };
  }, []);

  // Listen for action-chosen and route to inference
  useEffect(() => {
    const handleAction = (payload: {
      action: string;
      prompt: string;
      text: string;
    }) => {
      // Set voice state to processing
      useCursorStore.getState().setVoiceState("processing");

      // Route to inference via Electron API
      const api = window.electronAPI;
      if (api?.runInference) {
        api.runInference({ transcript: payload.prompt });
      }
    };

    eventBus.on("selection:action-chosen", handleAction);
    return () => {
      eventBus.off("selection:action-chosen", handleAction);
    };
  }, []);
}
