---
description: Run both backend and Flutter app simultaneously
---

# Run Full Stack (Backend + Flutter App)

## 1. Start Backend Server
// turbo
```
cd d:\health_care\backend && npx ts-node-dev --respawn --transpile-only src/index.ts
```
Wait for: `🌐 Server: http://0.0.0.0:5000`

## 2. Start Flutter App on Phone/Emulator
// turbo
```
cd d:\health_care && flutter run -d emulator-5554
```

> **Note**: Replace `emulator-5554` with your actual device ID. Run `flutter devices` to see connected devices.
