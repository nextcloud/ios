//
//  FloatingPlayerView.swift
//  Nextcloud
//
//  Created by Vitaliy Tolkach on 12.06.2025.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct FloatingPlayerView: View {
    @StateObject var viewModel = FloatingPlayerViewModel()
    private var presenter = FloatingPlayerViewPresenter.shared
    @State private var isCompact: Bool = true
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    private let cornerRadius: CGFloat = 10

    var body: some View {
        Group {
            if isCompact {
                compactPlayerView
            } else {
                expandedPlayerView
            }
        }
        .offset(dragOffset)
        .opacity(isDragging ? 0.8 : 1.0)
        .ignoresSafeArea(.all)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    let newPosition = CGPoint(
                        x: presenter.currentPosition.x + value.translation.width,
                        y: presenter.currentPosition.y + value.translation.height
                    )
                    presenter.updatePosition(newPosition)
                    dragOffset = .zero
                }
        )
    }

    private var compactPlayerView: some View {
        ZStack {
            Circle()
                .foregroundStyle(.gray)
                .brightness(0.25)

            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                .font(.title)
                .foregroundStyle(.black)
        }
        .frame(width: 50, height: 50)
        .onTapGesture {
            isCompact = false
            presenter.updateSize(isCompact)
        }
    }

    private var expandedPlayerView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .foregroundStyle(.gray)
                .brightness(0.25)

            VStack(spacing: 8) {
                Text(viewModel.fileName)
                    .font(.title3.bold())
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 20) {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .bold()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(.black, lineWidth: 1)
                        )
                        .onTapGesture {
                            isCompact = true
                            presenter.updateSize(isCompact)
                        }

                    Spacer()

                    Button {
                        viewModel.rewind()
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .frame(width: 44, height: 44)

                    Button {
                        viewModel.isPlaying ? viewModel.pause() : viewModel.play()
                    } label: {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .frame(width: 44, height: 44)

                    Button {
                        viewModel.forward()
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .frame(width: 44, height: 44)

                    Spacer()

                    Button {
                        viewModel.closePlayer()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .frame(width: 44, height: 44)
                }
            }
            .padding(8)
        }
        .foregroundStyle(.black)
    }
}

#Preview {
    FloatingPlayerView()
}
