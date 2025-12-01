# Funko Pop Database

This directory contains the Funko Pop database with enhanced variant tracking.

## Files

- `funko_pops.csv` - Complete database export containing Funko Pop information
- `funko_pops.json` - JSON format for easy app integration

## CSV Schema

The CSV file contains the following columns:

### Core Fields
- `HDBID` - Unique identifier
- `Name` - Pop name
- `Number` - Pop number
- `Series` - Series/category
- `Image URL` - Image URL
- `Description` - Product description
- `Category` - Category (Art Toys, Keychains, etc.)
- `Brand` - Brand (usually "Funko")
- `UPC` - Universal Product Code
- `Release Date` - Release date
- `Production Status` - Production status
- `Estimated Value` - Estimated value
- `Estimated Value Currency` - Currency (usually "USD")
- `Slug` - URL slug
- `Reference Number` - Reference number
- `Scale` - Scale/size
- `AKA` - Also known as
- `Catalog Item Type Name` - Item type
- `Scraped Date` - Date when data was scraped

### Variant Tracking Fields
- `is_master_variant` - `1` if master variant, `0` if subvariant
- `master_variant_hdbid` - HDBID of the master variant (empty if this is master)
- `variant_type` - `"master"` or `"subvariant"`
- `stickers` - Pipe-separated list of features (e.g., `"Chase|Glow in the Dark"`)
- `exclusivity` - Exclusivity information (e.g., `"Hot Topic"`, `"SDCC Shared"`)
- `is_autographed` - `1` if autographed, `0` otherwise
- `signed_by` - Name of signer (if autographed)
- `features` - Alias for stickers (same data)

## Usage

This data can be used to:
- Populate local database with Pop information
- Cross-reference Pop information
- Look up IDs for variant fetching
- Get UPC codes for Pop identification
- Display master variants in search
- Show all subvariants in pop detail view
- Filter autographed variants when toggled

## Last Updated

See `Scraped Date` column in CSV for individual record timestamps.

## Accessing from App

### Public Repository (Recommended)
If the repository is public, access the CSV directly:
```
https://raw.githubusercontent.com/nacliaf/PopCollector/main/data/database/funko_pops.csv
```

Or JSON:
```
https://raw.githubusercontent.com/nacliaf/PopCollector/main/data/database/funko_pops.json
```

## Variant Structure

The database includes master variants and subvariants:
- **Master variants**: `is_master_variant = 1`, `master_variant_hdbid` is empty
- **Subvariants**: `is_master_variant = 0`, `master_variant_hdbid` points to the master

Example:
- Master: Sung Jinwoo #1982 (is_master_variant=1)
- Subvariant 1: Sung Jinwoo #1982 Chase (is_master_variant=0, master_variant_hdbid=1982_master_hdbid)
- Subvariant 2: Sung Jinwoo #1982 Autographed (is_master_variant=0, master_variant_hdbid=1982_master_hdbid, is_autographed=1)
