//
//  PDFReaderView.swift
//  ZeroNet-Space
//
//  简洁的PDF阅读器组件
//  专注核心阅读体验
//

import PDFKit
import SwiftUI

struct PDFReaderView: View {
    let data: Data

    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex: Int = 0
    @State private var pageCount: Int = 0
    @State private var showControls: Bool = true
    @State private var autoHideTask: Task<Void, Never>?

    init(data: Data) {
        self.data = data
        _pdfDocument = State(initialValue: PDFDocument(data: data))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // PDF内容 - 全屏显示
            PDFKitView(
                data: data,
                document: pdfDocument,
                currentPageIndex: $currentPageIndex,
                pageCount: $pageCount
            )
            .ignoresSafeArea()
            .onTapGesture {
                toggleControls()
            }

            // 顶部控制条 - 浮动显示
            if showControls {
                VStack {
                    topControlBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }

            // 底部页码指示器 - 始终显示
            VStack {
                Spacer()
                pageIndicator
            }
        }
        .onAppear {
            resetAutoHide()
        }
    }

    // MARK: - UI Components

    private var topControlBar: some View {
        HStack(spacing: 16) {
            // 页码显示
            Text("\(currentPageIndex + 1) / \(pageCount)")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.15))
                .cornerRadius(8)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.black.opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            // 页面缩略图滑动条（简化版）
            if pageCount > 1 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景轨道
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)

                        // 进度指示器
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(
                                width: geometry.size.width / CGFloat(max(pageCount, 1)),
                                height: 4
                            )
                            .offset(
                                x: geometry.size.width * CGFloat(currentPageIndex)
                                    / CGFloat(max(pageCount - 1, 1)))
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 20)
            }
        }
        .frame(height: 60)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .opacity(showControls ? 1 : 0.3)
    }

    // MARK: - Control Functions

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls.toggle()
        }
        if showControls {
            resetAutoHide()
        } else {
            autoHideTask?.cancel()
        }
    }

    private func resetAutoHide() {
        autoHideTask?.cancel()
        autoHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showControls = false
                }
            }
        }
    }
}

// MARK: - PDFKit View

struct PDFKitView: UIViewRepresentable {
    let data: Data
    let document: PDFDocument?

    @Binding var currentPageIndex: Int
    @Binding var pageCount: Int

    final class PDFContainerView: UIView {
        let pdfView = PDFView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black

            pdfView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(pdfView)

            NSLayoutConstraint.activate([
                pdfView.topAnchor.constraint(equalTo: topAnchor),
                pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
                pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
                pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])

            // PDF显示设置
            pdfView.autoScales = true
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.backgroundColor = .black
            // 不使用pageViewController模式，避免导航方向错误
            pdfView.usePageViewController(false)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var parent: PDFKitView

        init(parent: PDFKitView) {
            self.parent = parent
        }

        @objc func pdfViewPageChanged(_ notification: Notification) {
            guard
                let pdfView = notification.object as? PDFView,
                let document = pdfView.document,
                let currentPage = pdfView.currentPage,
                let index = document.index(for: currentPage) as Int?
            else {
                return
            }

            DispatchQueue.main.async {
                self.parent.currentPageIndex = index
                self.parent.pageCount = document.pageCount
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PDFContainerView {
        let container = PDFContainerView()
        let pdfView = container.pdfView

        pdfView.delegate = context.coordinator

        if let activeDocument = document ?? PDFDocument(data: data) {
            pdfView.document = activeDocument
            pageCount = activeDocument.pageCount
            currentPageIndex = 0
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pdfViewPageChanged(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: pdfView
        )

        return container
    }

    func updateUIView(_ container: PDFContainerView, context: Context) {
        guard let document = container.pdfView.document else { return }

        // 更新总页数
        if pageCount != document.pageCount {
            pageCount = document.pageCount
        }

        // 根据当前页索引跳转
        if currentPageIndex >= 0 && currentPageIndex < document.pageCount {
            if let page = document.page(at: currentPageIndex),
                container.pdfView.currentPage != page
            {
                container.pdfView.go(to: page)
            }
        }
    }

    static func dismantleUIView(_ uiView: PDFContainerView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(
            coordinator,
            name: Notification.Name.PDFViewPageChanged,
            object: uiView.pdfView
        )
    }
}
