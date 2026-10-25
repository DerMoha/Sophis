# Partner sharing backend

Firebase Auth (email/password) and Firestore Security Rules on the Spark plan.
No Cloud Functions, Storage or billing account. The app talks to Firestore with
the `cloud_firestore` SDK, which also provides the offline cache and write queue.

## Data

| Path | Content |
| --- | --- |
| `partnerProfiles/{uid}` | `displayName`, `connectionId` (null when single) |
| `partnerInvites/{code}` | `inviterId`, `displayName`, `expiresAt` (24 h) |
| `partnerConnections/{id}` | `participants`, `names`, `invite`, `createdAt` |
| `partnerConnections/{id}/days/{uid}_{yyyy-MM-dd}` | `date`, `goals`, `burned`, `entries`, `updatedAt` |

Accepting a code is one batch: create the connection, link both profiles,
delete the invite. The rules only allow linking profiles that have no partner
yet, so each person has at most one. Disconnecting deletes the shared days,
the connection and unlinks both profiles.

Each client writes its last 7 diary days (one document per day, skipped when
unchanged) and watches the partner's day documents.

## Deploy

```sh
cd backend
firebase deploy --project sophis-d2953 --only firestore
```

## Test the rules

Runs against the local emulator with a demo project:

```sh
cd backend/rules-test
npm install
npm test
```
