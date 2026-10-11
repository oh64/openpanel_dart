# openpanel_dart example

Demo app for [openpanel_dart](../). Runs on **iOS, Android, Web, Windows,
macOS and Linux** (`flutter run -d <device>`).

## What it shows

- Cloud and **self-hosted** configuration
- `init`, `track`, `identify`, `increment`, groups (`upsertGroup` + `assignGroups`), `flush` and `clear`.
- Automatic helpers: `OpenpanelRouteObserver` (screen views), `OpenpanelReferrerObserver` (Android/iOS install referrer) and `OpenpanelLifecycleObserver` (queue flush on background/resume).
- A live activity log and the number of events still pending in the local queue.

## Run it

```bash
flutter run -d chrome        # web
flutter run -d linux         # linux desktop
flutter run                  # any connected device
```

Paste a client id from your OpenPanel dashboard (Project dashboard -> Settings -> Clients) and the URL of your instance (cloud or self-hosted), then press **Initialize**.
