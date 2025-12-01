#!/usr/bin/env python3
"""
HobbyDB Funko Pop Scraper
Scrapes hobbyDB API and saves to CSV with improved structure for variant handling.

Features:
- Scrapes from newest to oldest
- Tracks master variants and subvariants
- Resumes from last position
- Appends to file (never overwrites)
- Stops after 50 consecutive exact matches
- Includes all variant information (stickers, exclusivity, autographed status)
"""

import requests
import json
import csv
import time
import os
from datetime import datetime
from typing import Dict, List, Optional, Set
import hashlib

# Configuration
CSV_FILE = "data/hobbydb/funko_pops_hobbydb.csv"
PROGRESS_FILE = "data/hobbydb/scraper_progress.json"
API_BASE = "https://www.hobbydb.com/api"
BATCH_SIZE = 50  # Items per API request
DELAY_BETWEEN_REQUESTS = 1.0  # Seconds to wait between requests
STOP_AFTER_MATCHES = 50  # Stop after this many consecutive exact matches

# Headers to avoid detection
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.hobbydb.com/',
    'Origin': 'https://www.hobbydb.com'
}

def load_progress() -> Dict:
    """Load scraping progress from file"""
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {
        'last_index': 0,
        'last_hdbid': None,
        'total_scraped': 0,
        'last_scrape_date': None,
        'seen_hdbids': []
    }

def save_progress(progress: Dict):
    """Save scraping progress to file"""
    os.makedirs(os.path.dirname(PROGRESS_FILE), exist_ok=True)
    with open(PROGRESS_FILE, 'w') as f:
        json.dump(progress, f, indent=2)

def get_existing_hdbids() -> Set[str]:
    """Load existing HDBIDs from CSV to avoid duplicates"""
    seen = set()
    if os.path.exists(CSV_FILE):
        try:
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if 'hdbid' in row and row['hdbid']:
                        seen.add(row['hdbid'])
        except Exception as e:
            print(f"⚠️ Error reading existing CSV: {e}")
    return seen

def fetch_catalog_items(offset: int = 0, limit: int = BATCH_SIZE) -> Optional[Dict]:
    """Fetch catalog items from hobbyDB API"""
    url = f"{API_BASE}/catalog_items"
    
    # Build filters (Funko brand only)
    filters = {
        "brand": "380",  # Funko brand ID
        "in_collection": "all",
        "in_wishlist": "all",
        "on_sale": "all"
    }
    
    # Order by newest first (created_at desc)
    order = {
        "name": "created_at",
        "sort": "desc"
    }
    
    params = {
        "filters": json.dumps(filters),
        "order": json.dumps(order),
        "from_index": "true",
        "grouped": "false",
        "include_cit": "true",
        "include_count": "false",
        "include_last_page": "true",
        "include_main_images": "true",
        "limit": str(limit),
        "offset": str(offset)
    }
    
    try:
        response = requests.get(url, params=params, headers=HEADERS, timeout=30)
        response.raise_for_status()
        
        # Check if response is HTML (error page)
        if response.text.strip().startswith('<!'):
            print(f"⚠️ Received HTML instead of JSON at offset {offset}")
            return None
        
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"❌ Error fetching catalog items: {e}")
        return None
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing JSON: {e}")
        print(f"   Response preview: {response.text[:200]}")
        return None

def fetch_subvariants(hdbid: str) -> List[Dict]:
    """Fetch subvariants for a given HDBID"""
    url = f"{API_BASE}/catalog_items/{hdbid}/subvariants"
    
    try:
        response = requests.get(url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        
        if response.text.strip().startswith('<!'):
            return []
        
        data = response.json()
        if isinstance(data, dict) and 'data' in data:
            return data['data']
        elif isinstance(data, list):
            return data
        return []
    except Exception as e:
        # Silently fail for subvariants (not all items have them)
        return []

def extract_master_variant_info(item: Dict) -> Optional[str]:
    """Extract master variant HDBID from item data"""
    # Check if this item has a master_id field
    if 'master_id' in item and item['master_id']:
        return str(item['master_id'])
    
    # Check in catalog_item data
    if 'catalog_item' in item and isinstance(item['catalog_item'], dict):
        if 'master_id' in item['catalog_item']:
            return str(item['catalog_item']['master_id'])
    
    return None

def extract_stickers(item: Dict) -> List[str]:
    """Extract sticker/variant information from item"""
    stickers = []
    
    # Check prod_status field
    prod_status = item.get('prod_status', '').lower()
    name = item.get('name', '').lower()
    description = item.get('description', '').lower()
    
    # Feature keywords
    features = {
        'chase': 'Chase',
        'glow': 'Glow in the Dark',
        'gitd': 'Glow in the Dark',
        'metallic': 'Metallic',
        'flocked': 'Flocked',
        'chrome': 'Chrome',
        'blacklight': 'Blacklight',
        'diamond': 'Diamond',
        'gold': 'Gold',
        'translucent': 'Translucent',
        'scented': 'Scented'
    }
    
    search_text = f"{name} {prod_status} {description}"
    
    for keyword, label in features.items():
        if keyword in search_text and label not in stickers:
            # Skip false positives
            if keyword == 'diamond' and 'diamond select' in search_text:
                continue
            if keyword == 'gold' and 'golden' in search_text:
                continue
            stickers.append(label)
    
    return stickers

def extract_exclusivity(item: Dict) -> Optional[str]:
    """Extract exclusivity information (retailer, convention, etc.)"""
    name = item.get('name', '').lower()
    series = item.get('series', '').lower()
    description = item.get('description', '').lower()
    
    search_text = f"{name} {series} {description}"
    
    # Convention exclusives
    if 'sdcc' in search_text or 'san diego comic con' in search_text:
        if 'shared' in search_text:
            return 'SDCC Shared'
        return 'SDCC Exclusive'
    
    if 'nycc' in search_text or 'new york comic con' in search_text:
        if 'shared' in search_text:
            return 'NYCC Shared'
        return 'NYCC Exclusive'
    
    if 'eccc' in search_text or 'emerald city comic con' in search_text:
        if 'shared' in search_text:
            return 'ECCC Shared'
        return 'ECCC Exclusive'
    
    if 'anime expo' in search_text or ' ax ' in search_text:
        if 'shared' in search_text:
            return 'Anime Expo Shared'
        return 'Anime Expo Exclusive'
    
    if 'ccxp' in search_text:
        if 'shared' in search_text:
            return 'CCXP Shared'
        return 'CCXP Exclusive'
    
    if 'limited edition supreme' in search_text:
        return 'Limited Edition Supreme'
    
    if 'limited edition' in search_text:
        return 'Limited Edition'
    
    # Retailer exclusives
    retailers = {
        'hot topic': 'Hot Topic',
        'gamestop': 'GameStop',
        'target': 'Target',
        'walmart': 'Walmart',
        'amazon': 'Amazon',
        'barnes & noble': 'Barnes & Noble',
        'barnes and noble': 'Barnes & Noble',
        'boxlunch': 'BoxLunch',
        'funko shop': 'Funko Shop',
        'entertainment earth': 'Entertainment Earth',
        'anime of the year': 'Anime of the Year',
        'supreme': 'Supreme'
    }
    
    for pattern, label in retailers.items():
        if pattern in search_text:
            return label
    
    return None

def is_autographed(item: Dict) -> bool:
    """Check if item is autographed"""
    name = item.get('name', '').lower()
    description = item.get('description', '').lower()
    slug = item.get('slug', '').lower()
    image_url = item.get('image_url', '').lower()
    
    search_text = f"{name} {description} {slug} {image_url}"
    
    autograph_keywords = [
        'autographed', 'autograph', 'signed', 'signed by',
        'signature', 'certified autograph', 'coa'
    ]
    
    return any(keyword in search_text for keyword in autograph_keywords)

def extract_signer_name(item: Dict) -> Optional[str]:
    """Extract signer name from item if autographed"""
    if not is_autographed(item):
        return None
    
    name = item.get('name', '')
    description = item.get('description', '')
    
    import re
    # Look for patterns like "signed by [name]" or "autographed by [name]"
    patterns = [
        r'signed\s+by\s+([^,()]+)',
        r'autographed\s+by\s+([^,()]+)',
        r'autograph\s+by\s+([^,()]+)'
    ]
    
    search_text = f"{name} {description}".lower()
    
    for pattern in patterns:
        match = re.search(pattern, search_text, re.IGNORECASE)
        if match:
            signer = match.group(1).strip()
            if signer and len(signer) > 2:
                return signer.title()
    
    return None

def process_item(item: Dict, master_hdbid: Optional[str] = None) -> Dict:
    """Process a single catalog item into CSV row format"""
    hdbid = str(item.get('id', item.get('hdbid', '')))
    
    # Determine if this is a master variant
    is_master = master_hdbid is None
    if not is_master:
        # Check if this item itself is marked as master
        master_id = extract_master_variant_info(item)
        is_master = master_id is None or master_id == hdbid
    
    # Extract all information
    stickers = extract_stickers(item)
    exclusivity = extract_exclusivity(item)
    autographed = is_autographed(item)
    signer = extract_signer_name(item) if autographed else None
    
    # Build CSV row
    row = {
        'hdbid': hdbid,
        'name': item.get('name', ''),
        'number': item.get('number', ''),
        'series': item.get('series', ''),
        'image_url': item.get('image_url', ''),
        'description': item.get('description', ''),
        'category': item.get('category', ''),
        'brand': item.get('brand', ''),
        'upc': item.get('upc', ''),
        'release_date': item.get('release_date', ''),
        'prod_status': item.get('prod_status', ''),
        'estimated_value': item.get('estimated_value', ''),
        'estimated_value_currency': item.get('estimated_value_currency', ''),
        'slug': item.get('slug', ''),
        'ref_number': item.get('ref_number', ''),
        'scale': item.get('scale', ''),
        'aka': item.get('aka', ''),
        'catalog_item_type_name': item.get('catalog_item_type_name', ''),
        'scraped_date': datetime.now().isoformat(),
        # New fields for variant handling
        'is_master_variant': '1' if is_master else '0',
        'master_variant_hdbid': master_hdbid or hdbid if not is_master else '',
        'variant_type': 'master' if is_master else 'subvariant',
        'stickers': '|'.join(stickers),  # Pipe-separated list
        'exclusivity': exclusivity or '',
        'is_autographed': '1' if autographed else '0',
        'signed_by': signer or '',
        'features': '|'.join(stickers)  # Alias for stickers
    }
    
    return row

def get_csv_headers() -> List[str]:
    """Get CSV column headers"""
    return [
        'hdbid', 'name', 'number', 'series', 'image_url', 'description',
        'category', 'brand', 'upc', 'release_date', 'prod_status',
        'estimated_value', 'estimated_value_currency', 'slug', 'ref_number',
        'scale', 'aka', 'catalog_item_type_name', 'scraped_date',
        'is_master_variant', 'master_variant_hdbid', 'variant_type',
        'stickers', 'exclusivity', 'is_autographed', 'signed_by', 'features'
    ]

def append_to_csv(rows: List[Dict], file_path: str):
    """Append rows to CSV file"""
    file_exists = os.path.exists(file_path)
    
    os.makedirs(os.path.dirname(file_path), exist_ok=True)
    
    with open(file_path, 'a', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=get_csv_headers())
        
        if not file_exists:
            writer.writeheader()
        
        for row in rows:
            writer.writerow(row)

def calculate_item_hash(item: Dict) -> str:
    """Calculate a hash of item data for duplicate detection"""
    # Use key fields that shouldn't change
    key_data = {
        'hdbid': str(item.get('id', item.get('hdbid', ''))),
        'name': item.get('name', ''),
        'number': item.get('number', ''),
        'upc': item.get('upc', ''),
        'image_url': item.get('image_url', '')
    }
    
    data_string = json.dumps(key_data, sort_keys=True)
    return hashlib.md5(data_string.encode()).hexdigest()

def main():
    """Main scraping function"""
    print("=" * 70)
    print("🚀 HobbyDB Funko Pop Scraper")
    print("=" * 70)
    print()
    
    # Load progress
    progress = load_progress()
    existing_hdbids = get_existing_hdbids()
    
    print(f"📊 Progress:")
    print(f"   - Last index: {progress['last_index']}")
    print(f"   - Total scraped: {progress['total_scraped']}")
    print(f"   - Existing in CSV: {len(existing_hdbids)}")
    print()
    
    # Start from last position
    offset = progress['last_index']
    consecutive_matches = 0
    total_new = 0
    total_updated = 0
    
    print(f"🔍 Starting scrape from offset {offset}...")
    print()
    
    try:
        while True:
            # Fetch batch
            print(f"📥 Fetching items {offset} to {offset + BATCH_SIZE}...")
            data = fetch_catalog_items(offset, BATCH_SIZE)
            
            if not data:
                print("⚠️ No data received, waiting before retry...")
                time.sleep(5)
                continue
            
            items = data.get('data', [])
            
            if not items:
                print("✅ No more items to scrape")
                break
            
            print(f"   ✅ Received {len(items)} items")
            
            # Process items
            new_rows = []
            batch_matches = 0
            
            for item in items:
                hdbid = str(item.get('id', item.get('hdbid', '')))
                
                if not hdbid:
                    continue
                
                # Check if we've seen this exact item before
                item_hash = calculate_item_hash(item)
                if hdbid in existing_hdbids:
                    batch_matches += 1
                    consecutive_matches += 1
                    # Still process to check for updates, but mark as existing
                    print(f"   ⚠️ HDBID {hdbid} already exists (match #{consecutive_matches})")
                    
                    # Stop if we've hit the limit
                    if consecutive_matches >= STOP_AFTER_MATCHES:
                        print()
                        print(f"🛑 Stopping: Found {STOP_AFTER_MATCHES} consecutive existing items")
                        print("   This means we've reached the end of new data")
                        break
                else:
                    consecutive_matches = 0  # Reset counter on new item
                    existing_hdbids.add(hdbid)
                    total_new += 1
                
                # Process master variant
                master_row = process_item(item)
                new_rows.append(master_row)
                
                # Fetch and process subvariants
                print(f"   🔍 Fetching subvariants for {hdbid}...")
                subvariants = fetch_subvariants(hdbid)
                
                if subvariants:
                    print(f"      ✅ Found {len(subvariants)} subvariants")
                    for subvariant in subvariants:
                        sub_hdbid = str(subvariant.get('id', subvariant.get('hdbid', '')))
                        if sub_hdbid and sub_hdbid not in existing_hdbids:
                            sub_row = process_item(subvariant, master_hdbid=hdbid)
                            new_rows.append(sub_row)
                            existing_hdbids.add(sub_hdbid)
                            total_new += 1
                            time.sleep(0.5)  # Small delay for subvariants
                else:
                    print(f"      ℹ️ No subvariants")
                
                time.sleep(0.2)  # Small delay between items
            
            # Append to CSV
            if new_rows:
                print(f"💾 Appending {len(new_rows)} rows to CSV...")
                append_to_csv(new_rows, CSV_FILE)
                total_updated += len(new_rows)
            
            # Update progress
            offset += len(items)
            progress['last_index'] = offset
            progress['total_scraped'] += len(items)
            progress['last_scrape_date'] = datetime.now().isoformat()
            save_progress(progress)
            
            print(f"   ✅ Batch complete. Total new: {total_new}, Total updated: {total_updated}")
            print()
            
            # Check stop condition
            if consecutive_matches >= STOP_AFTER_MATCHES:
                break
            
            # Rate limiting
            time.sleep(DELAY_BETWEEN_REQUESTS)
            
    except KeyboardInterrupt:
        print()
        print("⚠️ Scraping interrupted by user")
    except Exception as e:
        print()
        print(f"❌ Error during scraping: {e}")
        import traceback
        traceback.print_exc()
    finally:
        # Save final progress
        save_progress(progress)
        print()
        print("=" * 70)
        print("📊 Final Statistics:")
        print(f"   - Total new items: {total_new}")
        print(f"   - Total rows added: {total_updated}")
        print(f"   - Last offset: {offset}")
        print(f"   - Progress saved to: {PROGRESS_FILE}")
        print("=" * 70)

if __name__ == "__main__":
    main()

