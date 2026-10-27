# Emerald knowledge system

Petya, 2026-10-27: "i want you to build a knowledge system so that we keep getting better and really learn. like a deep
neural network." This folder is that system: plain text in git, read first by every session, checked by number.

## The layers (the network)
| Layer | File | What it is |
|---|---|---|
| RULES | [rules.md](rules.md) | the weights: every rule the user gave, `R-nn`, with its quote, date, gate and where it was applied |
| LESSONS | [lessons.md](lessons.md) | the gradients: every mistake, `L-nn`: symptom, wrong model, cause, fix, proof, rules it taught |
| GATES | [gates.md](gates.md) | the loss function: the checks that prove a rule holds, `G-nn`, each with its command and target |
| SCORECARD | [scorecard.md](scorecard.md) / [scorecard.tsv](scorecard.tsv) | the training curve: one row per gate run, committed, so "are we getting better" is a number |
| FEEDBACK | [journal.md](journal.md) + `tools/knowledge/learn.py` | backprop: a user correction becomes rule + lesson + gate in one call; one "what I learned" line per session |

Ids are stable and never renumbered. A rule that stops being true gets `Status: superseded by R-mm`, never deleted.

## Reading order for a new session (about 6k tokens, nothing else before [NOW])
1. this file;
2. [rules.md](rules.md), all of it (the rules are short; the user corrected two builder rounds today because a session had not read them);
3. the last 10 lines of [journal.md](journal.md);
4. `.claude/handoffs/PLAN.md`: the Handoff section for the `[NOW]` task, then only the files it names.
Memory files under `~/.claude/projects/-Users-user-Documents-Emerald/memory/` are pointers and background; the rules here win when they disagree.

## Feedback protocol (one correction = one step)
1. The user corrects something (a chat line, a screenshot, "completely mangled"): quote it verbatim into a new rule, or into the
   `Source` of the rule it sharpens, with the date:
   `python3 tools/knowledge/learn.py rule "Title" --group "World shape" --rule "..." --source "user 2026-10-27: \"...\"" --gate G-02`
2. If a round was wrong, write the lesson the same minute, while the wrong model is still clear:
   `python3 tools/knowledge/learn.py lesson "Title" --symptom "..." --wrong "..." --cause "..." --fix "..." --proof "..." --rules R-04`
3. If no gate would have caught it, add a `G-nn` entry (even before the tool exists) and name it in the rule's `Gate:` line.
4. Before a handoff: `python3 tools/knowledge/learn.py journal "one line: what this session learned that the next one must not re-learn"`.
5. After every install: `bash tools/knowledge/run_gates.sh <label>` (field + class + tree gates, then a scorecard row), commit the
   row with the install. `python3 tools/knowledge/check.py` lints the files (ids, links, dates); `learn.py` runs it for you.

## Why this and not more memory files
Memory files are one fact each, written by whoever heard it, and nothing measures them. Here a rule carries its gate, the gate
carries its numbers, and the scorecard shows whether the numbers move. The user sees progress as a table, not as a promise.
