/**
 * Worker command guard for Pi.
 * Blocks HPC cluster jobs, pushes, merges, and PR merges from worker sessions.
 * This is a guardrail, not a sandbox: a determined process can still bypass it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const FORBIDDEN: ReadonlyArray<{ re: RegExp; reason: string }> = [
  { re: /\b(sbatch|srun)\b/i, reason: "HPC cluster jobs are not allowed for workers; put the command in the report for a human." },
  { re: /\bgit\s+push\b/i, reason: "Workers must not push; the integrator/human pushes after approval." },
  { re: /\bgh\s+pr\s+merge\b/i, reason: "Workers must not merge pull requests." },
  { re: /\bgit\s+merge\b/i, reason: "Workers must not merge branches; integration is a separate step." },
];

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (event.toolName !== "bash") return undefined;
    const command = String(event.input.command ?? "");
    for (const rule of FORBIDDEN) {
      if (rule.re.test(command)) {
        return { block: true, reason: rule.reason };
      }
    }
    return undefined;
  });
}
