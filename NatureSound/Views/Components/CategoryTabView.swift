//
//  CategoryTabView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

// MARK: - 分类标签栏
struct CategoryTabView: View {
    @Binding var selectedCategory: SoundCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SoundCategory.allCases) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category,
                        onTap: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 分类标签
struct CategoryChip: View {
    let category: SoundCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: category.icon).font(.system(size: 11, weight: .medium))
                Text(category.rawValue).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.15) : Color.clear)
                    .overlay(Capsule().stroke(Color.white.opacity(isSelected ? 0.3 : 0.1), lineWidth: 1))
            )
            .foregroundStyle(Color.white.opacity(isSelected ? 0.95 : 0.5))
        }
        .buttonStyle(.plain)
    }
}
