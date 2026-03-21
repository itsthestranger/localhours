# LocalHours Release Checklist

Use this checklist before publishing a GitHub release.

## 1) Workspace and Version Prep

- [ ] `git status` is clean
- [ ] `plasmoid/package/metadata.json` has the intended `KPlugin.Version`
- [ ] `README.md` reflects current install/update behavior
- [ ] `LICENSE` is present and correct (MIT)

## 2) Clean Install Smoke Test

Run on a test user profile/session:

```bash
./install.sh
```

Verify:

- [ ] install script completes without errors
- [ ] applet is available in Plasma widget list
- [ ] `systemctl --user status localhours` is active/running
- [ ] D-Bus endpoint responds:

```bash
gdbus introspect --session --dest org.kde.plasma.localhours --object-path /org/kde/plasma/localhours
```

## 3) Update-In-Place Smoke Test

With an existing install and some data present:

```bash
./install.sh
```

Verify:

- [ ] update succeeds without uninstall
- [ ] existing projects/sessions remain intact
- [ ] widget still loads and daemon reconnects

## 4) Uninstall Smoke Test

```bash
./uninstall.sh
```

Verify:

- [ ] service disabled/stopped
- [ ] applet removed
- [ ] data retention prompt behaves as expected

Reinstall again after uninstall to confirm recovery:

```bash
./install.sh
```

- [ ] reinstall works after uninstall path

## 5) Runtime Functional Checks

In the widget UI:

- [ ] create project
- [ ] start and stop tracking
- [ ] edit project name/color/metric toggles and explicitly save
- [ ] back-navigation does not auto-save unsaved edits
- [ ] edit session timestamps and delete session
- [ ] delete project with confirmation dialog

## 6) Settings and Failsafe Checks

From widget settings:

- [ ] clear `dataFilePath` and confirm default path is used
- [ ] set custom `dataFilePath` and confirm daemon reloads data
- [ ] adjust `maxSessionHours` and confirm setting applies while daemon is running
- [ ] set `maxSessionHours=0` and verify disabled-cap behavior

## 7) Logs and Diagnostics

- [ ] no unexpected daemon crashes/restart loops in logs:

```bash
journalctl --user -u localhours -n 100
```

- [ ] restart command works:

```bash
systemctl --user restart localhours
```

- [ ] status remains healthy after restart

## 8) Release Metadata and Links

- [ ] `metadata.json` has correct website URL:
  - `https://github.com/itsthestranger/localhours`
- [ ] `localhours.service` has working `Documentation=` URL
- [ ] GitHub repository description/topics are up to date

## 9) GitHub Release Steps

- [ ] merge/rebase release branch to `main`
- [ ] create annotated tag:

```bash
git tag -a vX.Y.Z -m "LocalHours vX.Y.Z"
git push origin vX.Y.Z
```

- [ ] create GitHub release for tag `vX.Y.Z`
- [ ] include concise changelog and upgrade notes
- [ ] attach screenshots/gif if available

## 10) Post-Release Verification

- [ ] clone repo fresh and run install path once
- [ ] confirm README commands still work exactly as written
- [ ] confirm issue template/support instructions are discoverable
