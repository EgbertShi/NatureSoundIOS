//
//  ContentView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

struct ContentView: View {
    @State private var audioManager = AudioManager()
    @State private var timerManager = TimerManager()
    @State private var sceneManager = SceneManager()
    @State private var selectedTab = 0
    @State private var showStandby = false
    @State private var standbyMode: StandbyMode = .immersive
    @State private var showPlayer = false
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    private let tabs: [(title: String, icon: String)] = [("声音", "waveform"), ("场景", "square.stack.3d.up.fill"), ("我的", "star.fill")]

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundGradient
            backgroundParticles

            VStack(spacing: 0) {
                headerView
                pageTabBar.padding(.top, 8)
                TabView(selection: $selectedTab) {
                    SoundsPage(audioManager: audioManager).tag(0)
                    ScenesPage(audioManager: audioManager, sceneManager: sceneManager).tag(1)
                    MyScenesPage(audioManager: audioManager, sceneManager: sceneManager).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            if audioManager.activeCount > 0 {
                MiniPlayerBar(audioManager: audioManager, timerManager: timerManager)
                    .onTapGesture { showPlayer = true }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: audioManager.activeCount)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerPage(audioManager: audioManager, timerManager: timerManager, sceneManager: sceneManager, showStandby: $showStandby, standbyMode: $standbyMode, isPresented: $showPlayer)
        }
        .fullScreenCover(isPresented: $showStandby) {
            StandbyView(audioManager: audioManager, timerManager: timerManager, mode: standbyMode, isPresented: $showStandby)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { audioManager.resumeAll() }
        }
        .onChange(of: timerManager.fadeOutProgress) { _, progress in
            audioManager.applyFadeOut(progress: progress)
        }
        .sheet(isPresented: $showSettings) {
            SettingsPage(audioManager: audioManager, sceneManager: sceneManager, isPresented: $showSettings)
                .presentationDetents([.medium])
        }
    }

    // MARK: - 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "0F0C29"), Color(hex: "1A1A2E"), Color(hex: "16213E")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - 背景装饰
    private var backgroundParticles: some View {
        ZStack {
            Circle().fill(Color(hex: "667eea").opacity(0.05)).frame(width: 300, height: 300).blur(radius: 80).offset(x: -100, y: -200)
            Circle().fill(Color(hex: "764ba2").opacity(0.05)).frame(width: 250, height: 250).blur(radius: 70).offset(x: 120, y: 100)
            Circle().fill(Color(hex: "0097A7").opacity(0.03)).frame(width: 200, height: 200).blur(radius: 60).offset(x: -50, y: 300)
        }
    }

    // MARK: - 页面切换标签
    private var pageTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.spring(response: 0.3)) { selectedTab = index }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon).font(.system(size: 16, weight: .medium))
                        Text(tab.title).font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == index ? Color.white.opacity(0.9) : Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(selectedTab == index ? Color.white.opacity(0.08) : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 顶部标题
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("清籁")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color.white.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                Text("聆听自然 · 疗愈心灵")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()

            HStack(spacing: 12) {
                if timerManager.isActive {
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.system(size: 11)).foregroundStyle(Color(hex: "FF6B6B"))
                        Text(timerManager.displayTime).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Color(hex: "FF6B6B"))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "FF6B6B").opacity(0.15)))
                }

                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 3).frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(audioManager.activeCount) / CGFloat(AudioManager.maxConcurrentSounds))
                        .stroke(
                            LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: audioManager.activeCount)
                    Text("\(audioManager.activeCount)").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Color.white.opacity(0.8))
                }

                Button {
                    Haptics.light()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

#Preview {
    ContentView()
}
