# Scoping a solved issue

Single source of truth for establishing which repos an issue's work landed in. `GR-review`,
`GR-rebase`, `GR-pr`, and `GR-squash-merge` all point here.

The issue is `EvoWorkforce/GR-documentation#<n>`. Its linked branches are authoritative:

```sh
gh api graphql -f query='{repository(owner:"EvoWorkforce",name:"GR-documentation"){issue(number:<n>){
  title linkedBranches(first:20){nodes{ref{name repository{nameWithOwner}}}}}}}'
```

Locally-created branches never appear there, so also run `git -C <repo> branch --list "<n>-*"` across
`${HOME}/gitroot` and reconcile the two lists. A repo missing here is a repo that silently does not
get reviewed, verified, PR'd, or landed.

For each candidate, confirm from real output that `git log --oneline main..HEAD` is non-empty — a
branch with nothing ahead needs nothing done to it.

Report the repo/branch table and stop. Ask whether it is complete; the caller decides what to do
with it.
