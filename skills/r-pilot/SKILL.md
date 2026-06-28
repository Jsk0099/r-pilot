---
name: r-pilot
description: >
  Review Pilot branch code reviewer. Opens a browser UI that drives the entire review
  flow — no chat interaction needed after launch.
---

# Review Pilot — Server Launch

The server and browser UI are started silently by the `UserPromptSubmit` hook when you
type `/r-pilot` — no command is run from chat. The UI collects all inputs and drives the
complete review without any further chat interaction.

## Tell the user

Reply with exactly this — do not run any command:

> **Review Pilot is starting at http://localhost:3922** — the browser UI should open in a moment. Select your role and base branch there, then click **Start Review**. Progress and results appear in the browser. No further input needed here.
>
> If the browser didn't open, check `/tmp/reviewpilot-server.log`.

---

Do NOT ask any questions. Do NOT call AskUserQuestion. Do NOT invoke the r-pilot agent.
The browser UI handles the entire review — role selection, base branch, scope collection,
AI review, and fix approval. This skill's only job is to start the server and open the browser.
