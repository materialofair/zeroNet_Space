//
//  PhotosViewModel.swift
//  ZeroNet-Space
//
//  相片视图模型
//

import Foundation
import SwiftUI

@MainActor
class PhotosViewModel: ObservableObject {
    @Published var selectedSortOrder: MediaItem.SortOrder = .dateNewest
    @Published var isLoading = false
}
