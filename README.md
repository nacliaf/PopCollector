# PopCollector - Funko Pop Collection Tracker

A complete iOS app for tracking your Funko Pop collection with real-time pricing from eBay, Mercari, and other marketplaces.

## Features

✅ **Barcode Scanner** - Scan Pop boxes to instantly add them with auto-detected name & photo  
✅ **UPC Lookup** - Automatically identifies Pop name, number, series, and image from barcode  
✅ **Real-time Pricing** - Average prices from eBay and Mercari (last 30 days)  
✅ **Smart eBay Integration** - Uses API if available, automatically falls back to HTML scraping  
✅ **Per-User API Keys** - Each user can add their own eBay key (stored securely in Keychain)  
✅ **Price Trends** - See if prices are going up or down with percentage changes  
✅ **Custom Folders/Bins** - Create unlimited custom-named bins to organize your collection  
✅ **Wishlist** - Track Pops you want  
✅ **Marketplace Search** - Find deals on eBay and Mercari  
✅ **Dark Mode** - Beautiful UI that adapts to your system settings  
✅ **Offline Support** - Works without internet using SwiftData  
✅ **iCloud Sync** - (Coming soon) Sync across devices  

## Data

The `data/` directory contains database exports and scraped data:

- `data/hobbydb/` - HobbyDB Funko Pop database export (CSV format)
  - Contains ~35,000+ Pop records with HDBIDs, UPCs, and metadata
  - Used for cross-referencing and variant lookup
  - See `data/hobbydb/README.md` for schema details

## Setup Instructions

### 1. Install Xcode
- Download from Mac App Store (free, ~12GB)
- Open Xcode and let it install additional components

### 2. Open This Project
- Open Xcode
- File → Open → Select the `PopCollector.xcodeproj` file
- Or create a new project and copy these files into it

### 3. Add SwiftSoup Package (Required for Mercari Scraping)
1. In Xcode, go to **File** → **Add Packages...**
2. Enter: `https://github.com/scinfu/SwiftSoup`
3. Click **Add Package**
4. Make sure it's added to your app target

### 4. Configure eBay API (Optional but Recommended)
1. Go to https://developer.ebay.com/
2. Sign up for a free developer account
3. Create a new app to get your App ID
4. Open the app → Go to **Settings** tab
5. Paste your eBay App ID in the text field
6. Tap **Save Key** (stored securely in Keychain)

**Note:** If you don't add a key, the app will automatically use HTML scraping (still works great!)

### 5. Run the App
- Connect your iPhone or use the iOS Simulator
- Click the ▶️ Play button in Xcode
- Allow camera permissions when prompted

## Project Structure

```
PopCollector/
├── PopCollectorApp.swift      # App entry point
├── Models/
│   ├── PopItem.swift          # Pop data model
│   └── PopFolder.swift       # Custom folder/bin model
├── Views/
│   ├── ContentView.swift      # Main tab view
│   ├── DiscoverView.swift     # Browse/search
│   ├── CollectionView.swift   # Your collection with custom bins
│   ├── WishlistView.swift     # Wishlist
│   ├── ShopView.swift         # Marketplace
│   ├── SettingsView.swift     # Per-user eBay API key settings
│   └── ScannerView.swift      # Barcode scanner
├── Services/
│   ├── PriceFetcher.swift     # Price fetching (API + HTML fallback)
│   ├── UPCLookup.swift        # UPC to Pop name/image lookup
│   └── KeychainHelper.swift   # Secure key storage
└── Info.plist                 # App permissions
```

## How to Use

### Adding a Pop
1. Go to the **Collection** tab
2. Tap **"Scan a Pop"**
3. Point camera at barcode on Pop box
4. App automatically:
   - Looks up Pop name, number, series, and image from UPC
   - Fetches current market price from eBay & Mercari
   - Adds to your collection

### Organizing Pops into Custom Bins
1. Tap **"New Bin"** button (top left)
2. Enter a custom name (e.g., "Living Room Shelf", "Vaulted Grails")
3. Tap **Create**
4. To move a Pop to a bin:
   - Tap the folder icon on any Pop
   - Select which bin to move it to
   - Or select "No Folder" to remove from bin

### Refreshing Prices
- Pull down on Collection list to refresh
- Or tap the refresh button in the toolbar
- Prices update from both eBay and Mercari
- Trend arrows show if prices are going up (↑) or down (↓)

## Next Steps

- [x] UPC lookup database (auto-detects Pop name/image from barcode)
- [x] Improve Mercari HTML parsing (SwiftSoup integrated)
- [x] Price trend tracking
- [x] Custom folder/bin management UI
- [x] Per-user eBay API keys (Keychain storage)
- [x] eBay HTML scraping fallback
- [ ] Implement sharing/export
- [ ] Add price alerts (notifications when trend changes)
- [ ] iCloud sync

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Notes

- **SwiftSoup is required** - Make sure to add it via Swift Package Manager
- **eBay API Key (Optional):** Add your own key in Settings for faster, more accurate pricing. If no key is added, the app automatically uses HTML scraping (works great!)
- **UPC Lookup:** Uses free APIs (UPCItemDB, OpenFoodFacts) with Google image search fallback
- **Pricing:** Combines eBay and Mercari sold listings from last 30 days for accurate averages
- **Price Trends:** Calculated by comparing current vs previous prices
- **Custom Bins:** Create unlimited custom-named folders to organize your collection however you want
- All data is stored locally using SwiftData (no backend needed)
- API keys are stored securely in iOS Keychain

## Support

If you encounter any issues:
1. Check that camera permissions are enabled in Settings
2. Make sure you're running on iOS 17.0 or later
3. Verify your eBay API key is correct (if using real pricing)

---

Built with ❤️ using SwiftUI

