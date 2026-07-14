//
//  WelcomeView.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import SwiftUI

struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool
    @State private var currentPage = 0
    @State private var opacity: Double = 0

    private let pages: [(icon: String, title: String, subtitle: String, color: String)] = [
        ("waveform.path.ecg", "30 种自然声音", "溪流、鸟鸣、雷声、虫鸣……\n全部由算法实时合成，无需下载音频文件", "667eea"),
        ("slider.horizontal.3", "自由混合叠加", "最多同时播放 7 种声音\n独立调节每个声音的音量", "764ba2"),
        ("square.stack.3d.up.fill", "一键场景切换", "14 个精选场景一键加载\n也可以保存你自己的专属组合", "0097A7"),
        ("moon.zzz.fill", "睡眠定时", "设定时间后自动停止播放\n伴你安心入眠", "EC407A"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F0C29"), Color(hex: "1A1A2E"), Color(hex: "16213E")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 8) {
                    Text("清籁")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, Color.white.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    Text("聆听自然 · 疗愈心灵")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .padding(.bottom, 40)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 20) {
                            ZStack {
                                Circle().fill(Color(hex: page.color).opacity(0.15)).frame(width: 100, height: 100)
                                Image(systemName: page.icon).font(.system(size: 38, weight: .medium)).foregroundStyle(Color(hex: page.color))
                            }
                            Text(page.title).font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.white.opacity(0.9))
                            Text(page.subtitle).font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.5)).multilineTextAlignment(.center).lineSpacing(4)
                        }
                        .padding(.bottom, 40)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 320)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.3)) { hasSeenWelcome = true }
                } label: {
                    Text(currentPage == pages.count - 1 ? "开始体验" : "跳过引导")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(colors: [Color(hex: "667eea"), Color(hex: "764ba2")], startPoint: .leading, endPoint: .trailing))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .opacity(opacity)
        .onAppear { withAnimation(.easeIn(duration: 0.5)) { opacity = 1 } }
    }
}
