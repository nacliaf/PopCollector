# 📱 Widget Setup Guide

## Overview

The PopCollector widget extension provides three sizes:
- **Small**: Total collection value
- **Medium**: Value + key stats
- **Large**: Full stats + recent additions + most valuable

## Setup Steps

### 1. Create Widget Extension Target

1. In Xcode, go to **File** → **New** → **Target**
2. Select **Widget Extension**
3. Name it: `PopCollectorWidget`
4. Choose **Include Configuration Intent** (for customization)
5. Click **Finish**

### 2. Add App Group

1. Select your **main app target**
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Add **App Groups**
5. Create new group: `group.com.popcollector.shared`
6. Repeat for **widget extension target**

### 3. Copy Widget Files

1. Copy `PopCollectorWidget.swift` to widget extension
2. Copy `WidgetDataManager.swift` to main app (or shared framework)
3. Make sure both targets can access SwiftData models

### 4. Update Widget Code

In `PopCollectorWidget.swift`, update the `loadWidgetData` method:

```swift
private func loadWidgetData(for type: WidgetType?) -> PopCollectorWidgetEntry {
    let widgetType = type ?? .totalValue
    
    // Load from shared App Group
    guard let widgetData = WidgetDataManager.shared.loadWidgetData() else {
        return placeholderEntry()
    }
    
    return PopCollectorWidgetEntry(
        date: Date(),
        totalValue: widgetData.totalValue,
        totalCount: widgetData.totalCount,
        uniqueCount: widgetData.uniqueCount,
        mostValuable: widgetData.mostValuable,
        recentPops: widgetData.recentPops,
        widgetType: widgetType
    )
}
```

### 5. Update App to Refresh Widget

The app already calls `WidgetDataManager.shared.updateWidgetData()` when:
- A Pop is added
- Prices are refreshed
- App launches

### 6. Add Widget to Home Screen

1. Long-press home screen
2. Tap **+** button
3. Search for "PopCollector"
4. Select widget size
5. Tap **Add Widget**

## Widget Types

### Small Widget
- Total collection value
- Total Pop count
- Clean, minimal design

### Medium Widget
- Total value (large)
- Unique count
- Total count
- Most valuable Pop

### Large Widget
- Full stats overview
- Most valuable Pop details
- Recent additions (last 3)
- Complete collection summary

## Customization

Users can customize widgets by:
1. Long-pressing widget
2. Tapping **Edit Widget**
3. Choosing widget type (if using App Intents)

## Troubleshooting

**Widget not updating?**
- Check App Group is configured in both targets
- Verify widget data is being saved
- Try removing and re-adding widget

**Widget shows placeholder?**
- Make sure you have Pops in your collection
- Check App Group permissions
- Verify shared container is accessible

**Build errors?**
- Make sure widget extension can access SwiftData models
- Check import statements
- Verify App Group identifier matches

## Testing

1. Run app and add some Pops
2. Add widget to home screen
3. Verify data appears correctly
4. Test all three sizes
5. Check widget updates when collection changes

---

**Note:** Widget extensions require iOS 14+ and a paid Apple Developer account for App Groups.

