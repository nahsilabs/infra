# Updating Hermes

Test upgrades, fixes, and integrations on Proba before promoting them to production.

## Prepare

1. Create a feature branch from `main`.
2. For an upgrade, read the production image pin. Review every release through the target version, including patches.
3. Update affected configuration and integrations. Remove obsolete workarounds and simplify the code you touch.

## Test on Proba

1. Protect Proba’s dedicated Flux source from parent reconciliation.
2. Point the source at the feature branch, reconcile Proba, and confirm the deployed revision.
3. Test the changed behavior.
4. For Hermes upgrades, verify that the Snapcompact patch still applies and that compaction and mode selection work.
5. If plugin installation changes, check the Langfuse installation step.

## Promote

1. Get approval, then merge the tested changes into `main`.
2. Restore Proba’s source to `main` and remove its temporary reconciliation protection.
3. Verify that production applies the change.

If you abandon the change, restore Proba’s source and reconciliation without merging.
