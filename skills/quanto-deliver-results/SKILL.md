---
name: quanto-deliver-results
description: Send a QuantoBooks workflow's output to where the firm actually works — Slack, Notion, or email — instead of leaving it in the chat. The delivery half of the orchestration loop: ad-hoc runs hand off here when the user wants a result sent, and scheduled runs bake a destination in so the report is waiting in the right place when it fires. Trigger phrases — "send this to Slack", "post this to Notion", "email me this", "where should this go", "deliver the report", "notify the team", "drop this in [channel]".
---

# Deliver Results

Follow the rules in `quanto-client-context` first — what you deliver is client data, so the active-client and flag rules still apply.

This skill owns one concern: **getting a workflow's output out of the chat and into where the firm reads things.** It's the counterpart to `quanto-schedule-workflow` (which owns *when* a workflow runs) and `quanto-report-templates` (which owns *how a visual looks*). Automation an accountant can't get notified about isn't really automation — this is the piece that closes that gap.

## The one safety distinction: internal vs. client-facing

Delivery is an outbound action, so draw a hard line:

- **Internal delivery is safe** — even unattended. Posting a read-only summary or report to the *firm's own* Slack channel, Notion space, or the user's email is the whole point of scheduling. A scheduled run may do this with no human present.
- **Client-facing or write actions are human-in-the-loop** — always. Sending anything *to the client*, posting to a client-shared channel, or any QBO `_create` / `_update` / `_delete` or payment is never done unattended and never without explicit approval (`quanto-client-context` §3). If a destination is shared with the client, treat it as client-facing.

When in doubt about who can see a destination, ask — once — before sending.

## Destinations

Use whatever the host has connected. Don't assume; check, and if nothing's connected, say so and name the options.

| Destination | How | Notes |
|-------------|-----|-------|
| **Slack** | `slack_send_message` to a channel or DM; `slack_schedule_message` to time it | Format as Slack-flavored markdown. Confirm the channel. A client-shared channel is client-facing — gate it. |
| **Notion** | Append the result to a page or database row via the Notion connector | Good for a durable per-client report log. Convert the markdown to Notion blocks. |
| **Email** | The host's email capability, if present | Clean subject + body. Treat any external recipient as client-facing. |
| **None connected** | Don't fake it | Tell the user no delivery destination is connected, name Slack / Notion / email, and point them to connect one in their host. Offer to keep the result inline meanwhile. |

## Playbook

### Step 1 — Know what you're delivering

Take the deliverable from the calling skill as-is (don't re-fetch or re-compute it). Note its sensitivity: is it an internal summary, or something client-facing? That decides which destinations are allowed without approval.

### Step 2 — Pick the destination

Inherit the default set at onboarding (the firm or client default from `quanto-ops-firm-onboarding` / `quanto-ops-client-onboarding`) if there is one — *"sending to your usual **#acme-ops** channel"* — and just confirm it. If there's no default, ask which connected destination to use. Don't interrogate; one question.

### Step 3 — Format for the destination

Reshape the deliverable for where it's going — Slack markdown, Notion blocks, or an email body with a subject. Keep the substance identical; only the formatting changes. For a polished visual, hand to `quanto-report-templates` first, then deliver the result.

### Step 4 — Confirm and send

- **Internal + a known default:** send, then confirm what landed where (with a link if the destination returns one).
- **Client-facing, a new destination, or any doubt:** show what you're about to send and where, get an explicit yes, then send.

### Step 5 — For scheduled runs

When this is invoked inside a scheduled (unattended) run, the destination was pinned at schedule time, so deliver without asking — but **only to an internal destination.** If the pinned destination is client-facing, do not send; instead deliver an internal "ready for your review" note so a human can release it. This keeps the `quanto-schedule-workflow` safety posture intact.

## Things to NEVER do

- Never send client-facing content unattended, or without explicit approval when a human is present.
- Never deliver to a destination you haven't confirmed is connected — no fabricated "sent to Slack."
- Never alter the substance of a result while formatting it for delivery — format, don't edit the findings.
- Never treat a shared / client channel as internal. If you're unsure who sees it, ask.

## Relationship to other skills

- Every workflow that produces a deliverable hands off here to send it — see the close-the-loop rule in `quanto-client-context`.
- `quanto-schedule-workflow` — pins a delivery destination into a recurring run so it delivers itself; this skill is what that run calls.
- `quanto-report-templates` — for a polished visual; format there, then deliver here.
- `quanto-ops-firm-onboarding` / `quanto-ops-client-onboarding` — set the firm / client default destinations this inherits.
