# HobbyDB Funko Pop Database

This directory contains scraped data from hobbyDB's Funko Pop database.

## Files

- `funko_pops_hobbydb.csv` - Complete database export from hobbyDB containing Funko Pop information

## CSV Schema

The CSV file contains the following columns:

- `hdbid` - HobbyDB unique identifier
- `name` - Pop name
- `number` - Pop number
- `series` - Series/category
- `image_url` - Image URL
- `description` - Product description
- `category` - Category (Art Toys, Keychains, etc.)
- `brand` - Brand (usually "Funko")
- `upc` - Universal Product Code
- `release_date` - Release date
- `prod_status` - Production status
- `estimated_value` - Estimated value
- `estimated_value_currency` - Currency (usually "USD")
- `slug` - URL slug
- `ref_number` - Reference number
- `scale` - Scale/size
- `aka` - Also known as
- `catalog_item_type_name` - Item type
- `scraped_date` - Date when data was scraped

## Usage

This data can be used to:
- Populate local database with hobbyDB information
- Cross-reference Pop information
- Look up HDBIDs for variant fetching
- Get UPC codes for Pop identification

## Data Source

Data scraped from: https://www.hobbydb.com

## Last Updated

See `scraped_date` column in CSV for individual record timestamps.

