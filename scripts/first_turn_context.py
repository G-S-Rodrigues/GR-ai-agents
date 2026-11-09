#!/usr/bin/env python3
"""Report what each kind of agent costs before it does any work.

    first_turn_context.py [--since YYYY-MM-DD] [--project SUBSTR] [--tools]

For every transcript under ~/.claude/projects (top-level sessions and
subagents), takes the first assistant turn's context size

    input_tokens + cache_read_input_tokens + cache_creation_input_tokens

and groups it by agent type (from the subagent's .meta.json; "top" for a
session) and model. Also reports the tool-schema bytes and skill-listing
characters the first request carried, from the transcript's prompt_snapshot
and skill_listing attachments. --tools lists the loaded tools per type, largest
first, which is where a fat first turn usually comes from.
"""
import argparse
import collections
import glob
import json
import os
import statistics


def first_turn(path):
    ctx = None
    tools = None
    skills = None
    started = None
    with open(path, "rb") as fh:
        for n, line in enumerate(fh):
            # The snapshot can land after the first turn; stop once both are
            # known, or a few hundred records in.
            if (ctx and tools) or n > 300:
                break
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if not isinstance(rec, dict):
                continue
            started = started or rec.get("timestamp")
            att = rec.get("attachment")
            if isinstance(att, dict):
                if att.get("type") == "prompt_snapshot" and att.get("tools"):
                    tools = tools or [
                        (t.get("name", "?"), len(json.dumps(t)))
                        for t in att["tools"]
                    ]
                elif att.get("type") == "skill_listing":
                    skills = skills or len(att.get("content", ""))
            msg = rec.get("message")
            if rec.get("type") == "assistant" and isinstance(msg, dict):
                u = msg.get("usage") or {}
                t = (u.get("input_tokens", 0)
                     + u.get("cache_read_input_tokens", 0)
                     + u.get("cache_creation_input_tokens", 0))
                if t and ctx is None:
                    ctx = (t, msg.get("model", "?"))
    return started, ctx, tools, skills


def agent_type(path):
    if "/subagents/" not in path:
        return "top"
    try:
        with open(path[: -len(".jsonl")] + ".meta.json") as fh:
            return json.load(fh).get("agentType", "general-purpose")
    except (OSError, ValueError):
        return "?"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--since", default="", help="first timestamp >= this")
    ap.add_argument("--project", default="", help="substring of the path")
    ap.add_argument("--tools", action="store_true", help="list loaded tools")
    args = ap.parse_args()

    root = os.path.expanduser("~/.claude/projects")
    groups = collections.defaultdict(
        lambda: {"ctx": [], "tool_bytes": [], "skills": [], "tools": None})
    for path in glob.glob(root + "/**/*.jsonl", recursive=True):
        if args.project and args.project not in path:
            continue
        started, ctx, tools, skills = first_turn(path)
        if not ctx or (started or "") < args.since:
            continue
        g = groups[(agent_type(path), ctx[1])]
        g["ctx"].append(ctx[0])
        if tools:
            g["tool_bytes"].append(sum(n for _, n in tools))
            g["tools"] = tools
        if skills:
            g["skills"].append(skills)

    print(f"{'agent type':<22}{'model':<20}{'runs':>5}{'median':>9}"
          f"{'min':>8}{'max':>8}{'toolKB':>8}{'skillKB':>8}")
    for (kind, model), g in sorted(groups.items(),
                                   key=lambda kv: -len(kv[1]["ctx"])):
        c = g["ctx"]
        tkb = (f"{statistics.median(g['tool_bytes']) / 1000:.0f}"
               if g["tool_bytes"] else "-")
        skb = (f"{statistics.median(g['skills']) / 1000:.1f}"
               if g["skills"] else "-")
        print(f"{kind:<22}{model:<20}{len(c):>5}"
              f"{int(statistics.median(c)):>9}{min(c):>8}{max(c):>8}"
              f"{tkb:>8}{skb:>8}")
        if args.tools and g["tools"]:
            ranked = sorted(g["tools"], key=lambda t: -t[1])
            print("    " + ", ".join(f"{n} {b // 1000}KB" for n, b in ranked))


if __name__ == "__main__":
    main()
