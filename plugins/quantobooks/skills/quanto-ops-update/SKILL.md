---
name: quanto-ops-update
description: Update the QuantoBooks skills plugin to the latest version, including the Cowork catalog-cache workaround when Update is greyed out or still shows an old version. USE THIS when someone says "update QuantoBooks", "get the latest quanto skills", "I'm on an old version", "the new quanto skill isn't showing up", "Update is greyed out", or after a QuantoBooks release. Checks installed vs latest version and walks the refresh → remove/re-add → restart cascade per environment. Trigger phrases — "update the QuantoBooks plugin", "get the latest skills", "new quanto version", "update is greyed out", "refresh QuantoBooks".
---

# Update QuantoBooks

Why this is finicky: **clients cache the marketplace catalog**, so "Update" often thinks the installed version is already the latest. Updating = **refresh the catalog first, then update the plugin** — and in Cowork, sometimes force a fresh fetch. You guide; the person performs the steps (in Claude Code you can read versions to confirm).

## Step 1 — Find the latest published version

Source of truth is `version.json` at the mirror root:
- https://github.com/quantotechnologylabs/quantobooks-skills/blob/main/version.json

In **Claude Code** you can compare directly:
```
# installed
cat ~/.claude/plugins/installed_plugins.json   # look for quantobooks@quantobooks
```
If installed == latest, there's nothing to do. If latest is higher, continue.

## Step 2 — Update

### Claude Code (terminal)
```
/plugin marketplace update quantobooks
/plugin update quantobooks@quantobooks
```
Then `/reload-plugins` or restart Claude Code. Re-check `installed_plugins.json`.

### Cowork — the cascade (do in order, stop when the version updates)
1. **Refresh + Update:** Customize → **Personal plugins** → **Quantobooks** → ensure it's **enabled** → click **Update**.
2. **If Update is greyed out or still shows the old version** (cache), force a fresh fetch by **removing and re-adding the marketplace** (the *marketplace*, not just the plugin):
   1. **⋮** (top-right) → remove the `quantobooks-skills` marketplace.
   2. **+** by Personal plugins → **Create plugin → Add marketplace** → `quantotechnologylabs/quantobooks-skills`.
   3. Install **quantobooks** from it and enable it — now on the latest.
3. **Still stale?** **Fully quit and reopen the Cowork app** (clears the in-memory catalog cache), then redo step 2.

### Claude Desktop
No marketplace updates — switch to Cowork / Claude Code, or re-upload the changed skills via the in-app Skills uploader from the dashboard bundle.

## Step 3 — Verify

Confirm the version moved to the latest from Step 1 (the number by the Cowork toggle, or `installed_plugins.json` in Claude Code), then sanity-check a skill that changed in the release — the `releaseNotes` in `version.json` say what's new. Restart so skills reload.

## Make this rarer

Enable **auto-update** for the `quantobooks` marketplace (Marketplaces tab) so refreshes happen automatically — you'll just get a reload nudge. A new version only appears once QuantoBooks bumps it; if a change "isn't showing up," confirm against the live `version.json` before running the cascade — it's usually a client cache issue, not a publish one.

## Things to NEVER do

- Never conclude "it's broken" without checking installed vs the live `version.json` — it's usually a cache, not a bug.
- Never tell a user to delete plugin files by hand — use the marketplace remove/re-add cascade.

## Relationship to other skills

- `quanto-ops-setup` — turns on auto-update during first-time setup; this skill is the manual path and the cache-cascade fix.
