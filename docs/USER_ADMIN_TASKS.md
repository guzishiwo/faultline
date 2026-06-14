# User and Admin Tasks

These tasks are scoped for GitHub Issues after the initial user/admin foundation.

## Completed in the Foundation Pass

- [x] Generate Phoenix auth for users.
- [x] Add `users.role` with `admin` and `member`.
- [x] Make the first registered user an admin.
- [x] Protect project and issue LiveViews behind login.
- [x] Add `/admin/users` for role management.
- [x] Prevent demoting the last admin.
- [x] Replace the Phoenix default homepage with a Faultline product entry page.

## Suggested GitHub Issues

### Add invite-only registration mode

Acceptance criteria:

- [ ] Admins can create an invitation for an email address.
- [ ] Registration can be disabled unless a valid invite token is present.
- [ ] Invite tokens expire.
- [ ] Tests cover valid, expired, and already-used invites.

### Add audit log for administrator actions

Acceptance criteria:

- [ ] Role changes write an audit log row with actor, target user, old role, and new role.
- [ ] Admin users can view recent audit log entries.
- [ ] Tests verify audit entries are written for successful role changes.

### Add organization membership

Acceptance criteria:

- [ ] Users can belong to one or more organizations.
- [ ] Organizations have roles separate from global admin.
- [ ] Projects belong to an organization.
- [ ] Project list and issue pages only show authorized organization data.

### Add project-level access control

Acceptance criteria:

- [ ] Admins can grant users access to specific projects.
- [ ] Project members can view issues but cannot manage global users.
- [ ] Ingest endpoints remain SDK-key based and do not require browser sessions.

### Add admin onboarding state

Acceptance criteria:

- [ ] When no users exist, the homepage points clearly to first admin registration.
- [ ] After the first admin exists, registration can be switched to invite-only.
- [ ] Tests cover first-user bootstrap behavior.
