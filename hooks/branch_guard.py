#!/usr/bin/env python3
"""PreToolUse guard on Bash: every new branch starts with an issue number, and every worktree
directory is named after its branch.

Reads the hook JSON on stdin. Exit 0 lets the command run; exit 2 blocks it, and stderr is what
the agent reads. Commands it cannot parse run unchecked: a guard that wedges a session costs more
than one misnamed branch.
"""
import json
import os
import re
import shlex
import sys

ISSUE_BRANCH = re.compile(r"^[0-9]+-[A-Za-z0-9]")
# The default branch is reset (`git checkout -B main origin/main`), never created for work.
DEFAULT_BRANCHES = {"main", "master"}
PUNCTUATION = set("();<>|&")
HEREDOC = re.compile(r"(?<!<)<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")
RULE = ("A branch is <issue>-<slug>, numbered by the GitHub issue that owns the work, or by a "
        "sub-issue of it for a part or fix added mid-run; its worktree is <repo>/.scratch/<branch>. "
        "See 'Issues, branches and worktrees' in ~/.claude/GR-references/where-documents-go.md.")

# `git branch` flags that list, delete, rename or configure rather than create.
BRANCH_HOUSEKEEPING = {
    "-d", "-D", "--delete", "-m", "-M", "--move", "-c", "-C", "--copy", "-l", "--list",
    "-a", "--all", "-r", "--remotes", "-v", "-vv", "--verbose", "--show-current",
    "--contains", "--no-contains", "--merged", "--no-merged", "--points-at", "--edit-description",
    "-u", "--set-upstream-to", "--unset-upstream", "--format", "--sort", "--column",
}
# Global git options that take a separate value.
GIT_VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}


def logical_lines(command):
    """Split at unquoted newlines, as the shell does, joining continued lines and dropping
    heredoc bodies, which are data rather than commands."""
    command = command.replace("\\\n", "")
    lines, cur, quote, i, n = [], [], None, 0, len(command)
    while i < n:
        c = command[i]
        if quote:
            if c == quote:
                quote = None
            elif c == "\\" and quote == '"' and i + 1 < n:
                cur.append(c)
                i += 1
                c = command[i]
        elif c in "'\"":
            quote = c
        elif c == "\\" and i + 1 < n:
            cur.append(c)
            i += 1
            c = command[i]
        elif c == "\n":
            line = "".join(cur)
            lines.append(line)
            cur, i = [], i + 1
            for m in HEREDOC.finditer(line):
                while i < n:  # skip the body through its delimiter line
                    end = command.find("\n", i)
                    end = n if end < 0 else end
                    body, i = command[i:end], end + 1
                    if body.strip() == m.group(2):
                        break
            continue
        cur.append(c)
        i += 1
    lines.append("".join(cur))
    return lines


def segments(command):
    """Yield each simple command's words, without redirections and their targets."""
    for line in logical_lines(command):
        lexer = shlex.shlex(line, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        seg, redirect_target = [], False
        for tok in lexer:
            if tok and set(tok) <= PUNCTUATION:
                if "<" in tok or ">" in tok:
                    if seg and seg[-1].isdigit():  # the fd in 2>
                        seg.pop()
                    redirect_target = True
                    continue
                if seg:
                    yield seg
                seg = []
            elif redirect_target:
                redirect_target = False
            else:
                seg.append(tok)
        if seg:
            yield seg


def git_subcommand(seg):
    """Return (subcommand, args) when seg runs git, else None."""
    while seg and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[0]):  # VAR=value prefixes
        seg = seg[1:]
    if not seg or os.path.basename(seg[0]) != "git":
        return None
    i = 1
    while i < len(seg) and seg[i].startswith("-"):
        i += 2 if seg[i] in GIT_VALUE_OPTS else 1
    if i >= len(seg):
        return None
    return seg[i], seg[i + 1:]


def value_after(args, flags):
    for j, a in enumerate(args):
        if a in flags and j + 1 < len(args):
            return args[j + 1]
        for f in flags:
            if f.startswith("--") and a.startswith(f + "="):
                return a.split("=", 1)[1]
    return None


def positionals(args, value_flags=()):
    out, skip = [], False
    for a in args:
        if skip:
            skip = False
        elif a in value_flags:
            skip = True
        elif a == "--" or not a.startswith("-"):
            if a != "--":
                out.append(a)
    return out


def unnumbered(name):
    return not ISSUE_BRANCH.match(name) and name not in DEFAULT_BRANCHES


def looks_like_local_branch(ref):
    return not ("/" in ref or ref == "HEAD" or re.fullmatch(r"[0-9a-f]{7,40}", ref)
                or ref.startswith(("HEAD~", "HEAD^")))


def problems(sub, args):
    if sub == "checkout":
        name = value_after(args, ["-b", "-B", "--orphan"])
        return [f"new branch '{name}' has no issue number"] if name and unnumbered(name) else []
    if sub == "switch":
        name = value_after(args, ["-c", "-C", "--create", "--force-create", "--orphan"])
        return [f"new branch '{name}' has no issue number"] if name and unnumbered(name) else []
    if sub == "branch":
        if any(a.split("=", 1)[0] in BRANCH_HOUSEKEEPING for a in args):
            return []
        pos = positionals(args)
        return [f"new branch '{pos[0]}' has no issue number"] if pos and unnumbered(pos[0]) else []
    if sub == "worktree" and args and args[0] == "add":
        rest = args[1:]
        if "--detach" in rest or "-d" in rest:
            return []
        new = value_after(rest, ["-b", "-B"])
        pos = positionals(rest, {"-b", "-B", "--reason"})
        if not pos:
            return []
        path, ref = pos[0], (pos[1] if len(pos) > 1 else None)
        dirname = os.path.basename(os.path.normpath(path))
        branch = new or (ref if ref and looks_like_local_branch(ref) else None)
        if branch is None and ref is None:
            branch = dirname  # git creates a branch named after the directory
        if branch is None:
            return []
        found = []
        if unnumbered(branch):
            found.append(f"branch '{branch}' has no issue number")
        if dirname != branch:
            found.append(f"worktree directory '{dirname}' is not named after its branch "
                         f"'{branch}' — use .scratch/{branch}")
        return found
    return []


def main():
    try:
        payload = json.load(sys.stdin)
        command = payload.get("tool_input", {}).get("command", "")
        if "git" not in command:
            return 0
        found = []
        for seg in segments(command):
            parsed = git_subcommand(seg)
            if parsed:
                found += problems(*parsed)
    except Exception:
        return 0
    if not found:
        return 0
    print("Blocked: " + "; ".join(found) + ". " + RULE,
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
