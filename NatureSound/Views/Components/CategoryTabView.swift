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
                    .fill(isSelected ? Theme.accent.opacity(0.1) : Theme.inactiveFill(.light))
                    .overlay(Capsule().stroke(isSelected ? Theme.accent.opacity(0.25) : Theme.cardBorder(.light), lineWidth: 1))
            )
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary(.light))
        }
        .buttonStyle(.plain)
    }
}
