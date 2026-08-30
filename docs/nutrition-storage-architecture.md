# Nutrition storage architecture

Sophis is offline-first. SQLite, accessed through `NutritionStore`, is the
authority for nutrition-owned state. Providers and controllers publish local
state only after a store command has committed successfully.

## Authorities

- Food, water, weight, workout, supplement, supplement-log, photo metadata,
  recipe, custom-food, favorite-food, planned-meal, custom-portion, shopping,
  goals, profile, and user-stat data live in SQLite.
- Normalized Drift rows are used for entity collections. Whole-collection
  replacement is reserved for migrations, backup restore, and explicit local
  cache operations.
- Recent foods remain a local-only SQLite document because meal presentation
  metadata belongs to the cache, not to sync state.
- SharedPreferences remains a compatibility layer for old installs and for
  device settings. Secrets remain in secure storage and are never in backup or
  sync payloads.

## Store contract

`NutritionStore.commit(NutritionCommand)` serializes commands, writes domain
data plus sync metadata/outbox rows in one transaction, and publishes a
snapshot only after commit. Entity writes use idempotent upserts. Deletes use
tombstone mutations; clear-all and restore use explicit snapshot mutations.

`NutritionStore.pendingSyncChanges()` exposes durable changes for a future
remote adapter. Changes include their `dataSpaceId`, deterministic mutation ID,
base revision, retry state, and operation. Processed rows can be pruned through
`pruneProcessedSyncChanges` after the remote has acknowledged them.

## Migration rules

Drift upgrades are gated by explicit schema versions through v11. The
`migration_state` table records the canonical library and account cutovers.
Legacy collection keys are selected by key presence, so an intentional empty
collection cannot resurrect stale rows. Failed initialization leaves its marker
unset and retries on the next attempt.

## Backup and photos

Backup archive v2 keeps its existing JSON representation. Photo files are
staged under randomized local names, written atomically, and removed by an
orphan sweep when a restore or commit fails. Cloud payloads never contain local
absolute paths; a progress photo mutation carries a stable `blobId` and a
string category key instead.

## Future cloud adapter

The backend-specific layer should consume the outbox without changing providers
or controllers. It must push idempotently by mutation ID, acknowledge only the
corresponding local revision, persist pull cursors and applied-change IDs in the
same local transaction as remote data, and upload photo bytes separately from
photo metadata. Conflict policy belongs in that adapter; local SQLite remains
the immediate read/write authority.
