# Project Settings Tabs Design

## Problem

The project settings page currently presents SDK setup, ingest limits, cost controls, drop rules, alert rules, and rule creation forms in one long vertical flow. The page has no clear primary workflow. This is especially weak because day-to-day usage is expected to focus on configuring rules, and future alert channels such as Feishu and DingTalk will make rule creation more complex.

## Goals

- Make rule management the default and most prominent workflow.
- Separate low-frequency setup and infrastructure settings from frequent rule configuration.
- Keep the page easy to extend as alert channels grow beyond email, generic webhook, and Slack.
- Preserve current LiveView behavior and existing route paths.
- Keep the design compatible with Phoenix LiveView tests by retaining stable DOM ids or replacing them with explicit new ids.

## Non-Goals

- Do not add Feishu or DingTalk delivery support in this change.
- Do not redesign project creation, issue triage, or usage pages.
- Do not change router scopes, authentication behavior, or project authorization.
- Do not add a new persisted user preference for the selected tab.

## Proposed Structure

The settings page becomes a tabbed interface under the existing page header.

Tabs:

- `Rules` default tab. This is the primary operational surface.
- `Ingest & retention` for rate limits, retention days, and event caps.
- `SDK setup` for DSN and copy actions.
- `Project` reserved for future project metadata or danger-zone actions. It can be omitted in the first implementation if there is no content yet.

The URL should support tab state with a query parameter, for example `/p/:slug/settings?tab=rules`. Invalid or missing tab values fall back to `rules`. This allows links and tests to open a specific settings area without adding new routes.

## Rules Tab

The `Rules` tab should read as a rule management workspace, not as a generic settings form.

Layout:

- Top summary row with compact counts for alert rules and drop rules, plus a primary `New rule` action.
- Main content uses segmented sections for `Alert rules` and `Drop rules`.
- Existing rules stay in stream-backed lists.
- Empty states stay visible but become smaller and action-oriented.
- Rule creation should move out of the always-visible right rail. Use an inline creation panel or drawer-like panel that appears after choosing the rule type.

Creation flow:

1. User clicks `New rule`.
2. User chooses rule family: `Alert rule` or `Drop rule`.
3. Alert rule form shows trigger, channel, target, threshold, and cooldown.
4. Drop rule form shows field, match, value, and enabled state.

Channel extensibility:

- Keep the alert rule form structured around a `channel` selection.
- Channel-specific helper text and placeholder should be driven from the selected channel.
- Current channels remain email, webhook, and Slack.
- Future channels such as Feishu and DingTalk should fit by adding channel metadata, not by adding one-off markup branches throughout the template.

## Ingest & Retention Tab

This tab contains the existing project cost controls form and the current ingest summary.

Layout:

- A compact summary row showing ingest limit, retention days, and event cap.
- The editable form below the summary.
- The save button remains within this tab.

This keeps operational limits available while removing them from the default rule workflow.

## SDK Setup Tab

This tab contains the DSN card and copy action.

Layout:

- `SDK DSN` card with `Copy DSN`.
- Optional short setup guidance can be added later, but the first pass should not duplicate the existing getting-started page.
- The `project-dsn` and copy button ids should remain stable for tests.

## LiveView Behavior

- Use LiveView assigns to track the active tab from params.
- Use `<.link patch={...}>` for tab changes so the page does not remount unnecessarily.
- Keep current form events for saving project settings, drop rules, and alert rules.
- Keep streams for `drop_rules` and `alert_rules`.
- When editing an existing alert rule, switch or stay on the `Rules` tab and reveal the alert rule form in edit mode.
- Creating or updating a rule should keep the user on `Rules`.

## Testing

Update `test/faultline_web/live/project_settings_live_test.exs` to cover:

- Default settings page opens on the `Rules` tab.
- Tab controls exist and patch to `rules`, `ingest`, and `sdk`.
- Existing alert rule and drop rule create/edit/toggle/delete flows still work from the `Rules` tab.
- `Ingest & retention` tab contains the cost controls form and persists updates.
- `SDK setup` tab contains the DSN and copy button.
- Invalid tab params fall back to `Rules`.

Run `mix precommit` after implementation.
