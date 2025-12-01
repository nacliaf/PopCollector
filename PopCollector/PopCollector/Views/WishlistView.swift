//
//  WishlistView.swift
//  PopCollector
//
//  Wishlist tab for tracking wanted Pops
//

import SwiftUI
import SwiftData

struct WishlistView: View {
    @Query(
        filter: #Predicate<PopItem> { $0.isInWishlist == true },
        sort: \PopItem.dateAdded,
        order: .reverse
    ) private var wishlistPops: [PopItem]
    
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    
    private var filteredPops: [PopItem] {
        if searchText.isEmpty {
            return wishlistPops
        }
        return wishlistPops.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.series.localizedCaseInsensitiveContains(searchText) ||
            $0.upc.contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            if wishlistPops.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "heart")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    
                    Text("Your wishlist is empty")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Add Pops to your wishlist from the collection view")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredPops) { pop in
                        WishlistPopRow(pop: pop)
                    }
                    .onDelete(perform: removeFromWishlist)
                }
                .searchable(text: $searchText, prompt: "Search wishlist...")
            }
        }
        .navigationTitle("Wishlist")
    }
    
    private func removeFromWishlist(at offsets: IndexSet) {
        for index in offsets {
            filteredPops[index].isInWishlist = false
        }
        try? context.save()
    }
}

struct WishlistPopRow: View {
    @Bindable var pop: PopItem
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack(spacing: 12) {
            OptimizedAsyncImage(url: pop.imageURL, width: 60, height: 60)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(pop.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if !pop.series.isEmpty {
                    Text(pop.series)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if pop.value > 0 {
                    Text("$\(pop.value, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Button {
                pop.isInWishlist = false
                try? context.save()
                Toast.show(message: "Removed from wishlist", systemImage: "heart.slash")
            } label: {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    WishlistView()
        .modelContainer(for: [PopItem.self, PopFolder.self], inMemory: true)
}

