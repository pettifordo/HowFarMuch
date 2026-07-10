# How Far/Much

An iPhone app that reads your workouts from Apple Health and adds them up —
how far, how long, how much (energy), and how many — over the past week,
month, or year, per activity type, with filters.

Local only: your Health data never leaves the device.

## Requirements

- Xcode 15+ (project generated with xcodegen)
- iOS 17+
- A real iPhone to see real workouts — the simulator shows clearly-badged demo data.

## Build

```bash
xcodegen generate        # regenerates HowFarMuch.xcodeproj (gitignored)
open HowFarMuch.xcodeproj
```

Or from the command line:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project HowFarMuch.xcodeproj -scheme HowFarMuch \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

To run on your iPhone, open the project in Xcode, select your development
team under Signing & Capabilities, and hit Run. On first launch the app asks
for read access to workouts, distances, and active energy — grant "Turn On All"
to see your totals.

## Structure

- `HowFarMuch/Models/` — `ActivityStats` aggregation, periods, metrics, activity-type display info
- `HowFarMuch/Services/HealthKitService.swift` — read-only HealthKit queries
- `HowFarMuch/ViewModels/SummaryViewModel.swift` — state + filtering
- `HowFarMuch/Views/` — dashboard, activity cards, logo

## Ideas for later

- AI weekly summary / coaching status (on-device or via the Claude API)
- Trends and personal records
- Widgets
