//
//  AudioSynthesis.swift
//  NatureSound
//
//  Created by egbert on 2026/7/1.
//

import AVFoundation

// MARK: - 音频合成引擎
/// 将 SoundItem 合成为 30 秒循环 PCM buffer 的所有算法。
enum AudioSynthesis {

    // MARK: - 渲染总入口
    static func render(sound: SoundItem, into buffer: AVAudioPCMBuffer, sampleRate sr: Double) {
        guard let L = buffer.floatChannelData?[0],
              let R = buffer.floatChannelData?[1] else { return }
        let N = Int(buffer.frameLength)

        let timeSeed = UInt64(Date().timeIntervalSince1970 * 100000)
        var idHash: UInt64 = 5381
        for ch in sound.id.utf8 { idHash = idHash &* 33 &+ UInt64(ch) }
        var rng = RNG(seed: timeSeed ^ idHash)

        var mono = [Float](repeating: 0, count: N)

        switch sound.category.rawValue {
        case SoundCategory.water.rawValue:   synWater(sound, &mono, sr, &rng)
        case SoundCategory.weather.rawValue: synWeather(sound, &mono, sr, &rng)
        case SoundCategory.bird.rawValue:    synBird(sound, &mono, sr, &rng)
        case SoundCategory.insect.rawValue:  synInsect(sound, &mono, sr, &rng)
        case SoundCategory.fire.rawValue:    synFire(sound, &mono, sr, &rng)
        case SoundCategory.zen.rawValue:     synZen(sound, &mono, sr, &rng)
        case SoundCategory.forest.rawValue:  synForest(sound, &mono, sr, &rng)
        case SoundCategory.ambient.rawValue: synAmbient(sound, &mono, sr, &rng)
        default:                              break
        }

        applyGlobalSoftening(&mono, sr: sr)
        applyCrossfade(&mono, sr: sr, fadeSeconds: 2.0)
        applyStereoWiden(mono, L: L, R: R, sr: sr, rng: &rng)
    }

    // MARK: - 后处理
    private static func applyGlobalSoftening(_ mono: inout [Float], sr: Double) {
        var softL = LP1(hz: 3500, sr: Float(sr))
        var softR = LP1(hz: 3200, sr: Float(sr))
        for i in 0..<mono.count { mono[i] = softL.tick(softR.tick(mono[i])) }
    }

    private static func applyCrossfade(_ mono: inout [Float], sr: Double, fadeSeconds: Double) {
        let fade = Int(sr * fadeSeconds)
        for i in 0..<min(fade, mono.count) {
            let g = Float(i) / Float(fade)
            let s = g * g * (3 - 2 * g)
            mono[i] *= s
            mono[mono.count - 1 - i] *= s
        }
    }

    private static func applyStereoWiden(_ mono: [Float], L: UnsafeMutablePointer<Float>, R: UnsafeMutablePointer<Float>, sr: Double, rng: inout RNG) {
        let pL = PerlinLFO(rng: &rng)
        let pR = PerlinLFO(rng: &rng)
        let panSpeedL = rng.range(0.08, 0.12)
        let panSpeedR = rng.range(0.08, 0.12)
        for i in 0..<mono.count {
            let t = Double(i) / sr
            L[i] = mono[i] * (1.0 + pL.sample(t: t, speed: panSpeedL) * 0.12)
            R[i] = mono[i] * (1.0 + pR.sample(t: t, speed: panSpeedR) * 0.12)
        }
    }

    // MARK: - 水流声
    private static func synWater(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let sid = sound.id
        let hz1: Float = sid == "ocean" ? 350 : sid == "waterfall" ? 1200 : sid == "drip" ? 1800 : sid == "fountain" ? 1400 : 700
        let hz2: Float = hz1 * 0.5

        var lp1 = LP1(hz: hz1, sr: Float(sr))
        var lp2 = LP1(hz: hz2, sr: Float(sr))
        var lp3 = LP1(hz: hz1 * 0.35, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let pn3 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.12, 0.3)
        let sp2 = rng.range(0.04, 0.1)
        let sp3 = rng.range(0.01, 0.04)

        var drips: [(t: Double, freq: Double, amp: Float)] = []
        if sid == "drip" {
            var dt = rng.range(0.3, 1.2)
            while dt < Double(out.count) / sr - 0.5 {
                drips.append((dt, rng.range(600, 1500), 0.12 + rng.f01() * 0.18))
                dt += rng.range(0.6, 3.5)
            }
        }

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lp3.tick(lp2.tick(lp1.tick(rng.signed())))
            s *= (0.7 + pn1.sample(t: t, speed: sp1) * 0.25 + pn2.sample(t: t, speed: sp2) * 0.2 + pn3.sample(t: t, speed: sp3) * 0.15)

            if sid == "ocean" {
                let w1 = pn1.sample(t: t, speed: rng.range(0.04, 0.1)) * 0.5
                let w2 = pn2.sample(t: t, speed: rng.range(0.015, 0.04)) * 0.35
                s *= max(0.1, 0.45 + w1 + w2)
            }
            if sid == "drip" {
                for d in drips {
                    let rel = t - d.t
                    guard rel >= 0 && rel < 0.12 else { continue }
                    s = s * 0.5 + Float(sin(t * d.freq * .pi * 2)) * Float(exp(-rel * 35)) * d.amp
                }
            }
            if sid == "fountain" {
                let bubble = pn1.sample(t: t, speed: 3.5)
                if bubble > 0.3 { s += bubble * 0.08 }
            }
            out[i] = s * 0.5
        }
    }

    // MARK: - 天气声
    private static func synWeather(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        switch sound.id {
        case "rain":     synRain(&out, sr, &rng)
        case "thunder":  synThunder(&out, sr, &rng)
        case "hail":     synHail(&out, sr, &rng)
        case "wind":     synWind(&out, sr, &rng)
        case "snowfall": synSnow(&out, sr, &rng)
        default:         synRain(&out, sr, &rng)
        }
    }

    private static func synRain(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 1200, sr: Float(sr))
        var lp2 = LP1(hz: 600, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.08, 0.18)
        let sp2 = rng.range(0.02, 0.06)
        let sp3 = rng.range(0.005, 0.02)

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lp2.tick(lp1.tick(rng.signed()))
            let intensity: Float = 0.55 + pn1.sample(t: t, speed: sp1) * 0.3 + pn1.sample(t: t, speed: sp2) * 0.2 + pn2.sample(t: t, speed: sp3) * 0.15
            s *= max(0.15, intensity)
            if rng.f01() > 0.9985 { s += rng.signed() * 0.15 }
            out[i] = s * 0.45
        }
    }

    private static func synThunder(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lpRain = LP1(hz: 500, sr: Float(sr))
        var lpRumble = LP1(hz: 60, sr: Float(sr))
        var lpRumble2 = LP1(hz: 40, sr: Float(sr))
        let pn = PerlinLFO(rng: &rng)
        let spRain = rng.range(0.06, 0.15)

        var strikes: [(t: Double, strength: Float)] = []
        var st = rng.range(1.0, 4.0)
        let total = Double(out.count) / sr
        while st < total - 2.0 {
            strikes.append((st, 0.3 + rng.f01() * 0.5))
            st += rng.range(2.5, 10.0)
        }

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lpRain.tick(rng.signed()) * 0.18
            s *= max(0.3, 0.7 + pn.sample(t: t, speed: spRain) * 0.2)
            for strike in strikes {
                let rel = t - strike.t
                guard rel >= 0 && rel < 3.5 else { continue }
                let rumble = lpRumble2.tick(lpRumble.tick(rng.signed()))
                let env = Float(exp(-rel * 0.7)) * strike.strength
                let crack: Float = rel < 0.05 ? Float(exp(-rel * 40)) * 0.3 : 0
                s += (rumble * env + crack) * 0.6
            }
            out[i] = s
        }
    }

    private static func synHail(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp = LP1(hz: 1400, sr: Float(sr))
        let pn = PerlinLFO(rng: &rng)
        let spPn = rng.range(0.1, 0.25)

        var hits: [(s: Int, len: Int, amp: Float)] = []
        let total = Double(out.count) / sr
        var ht: Double = 0.05
        let hitDurSamples = Int(0.015 * sr)
        while ht < total {
            hits.append((Int(ht * sr), hitDurSamples, 0.06 + rng.f01() * 0.2))
            ht += rng.range(0.03, 0.25)
        }
        for h in hits {
            for j in 0..<h.len {
                let idx = h.s + j
                guard idx < out.count else { break }
                out[idx] += rng.signed() * Float(exp(-Double(j) / sr * 250)) * h.amp
            }
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            out[i] += lp.tick(rng.signed()) * 0.1 * max(0.25, 0.7 + pn.sample(t: t, speed: spPn) * 0.25)
        }
    }

    private static func synWind(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 200, sr: Float(sr))
        var lp2 = LP1(hz: 120, sr: Float(sr))
        var lp3 = LP1(hz: 80, sr: Float(sr))
        var lpHi = LP1(hz: 280, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let pn3 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.04, 0.12)
        let sp2 = rng.range(0.12, 0.35)
        let sp3 = rng.range(0.015, 0.05)

        for i in 0..<out.count {
            let t = Double(i) / sr
            let low = lp3.tick(lp2.tick(lp1.tick(rng.signed())))
            let hi = lpHi.tick(rng.signed())
            let env = max(Float(0.08), 0.45 + pn1.sample(t: t, speed: sp1) * 0.35 + pn2.sample(t: t, speed: sp2) * 0.2 + pn3.sample(t: t, speed: sp3) * 0.25)
            out[i] = (low * 0.55 + hi * 0.15) * env * 0.7
        }
    }

    private static func synSnow(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 400, sr: Float(sr))
        var lp2 = LP1(hz: 250, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.03, 0.08)
        let sp2 = rng.range(0.08, 0.2)

        var rustles: [(s: Int, len: Int, amp: Float)] = []
        let total = Double(out.count) / sr
        var rt = rng.range(0.5, 2.0)
        let rustleLen = Int(0.08 * sr)
        while rt < total {
            rustles.append((Int(rt * sr), rustleLen, 0.08 + rng.f01() * 0.10))
            rt += rng.range(0.3, 1.5)
        }
        for r in rustles {
            for j in 0..<r.len {
                let idx = r.s + j
                guard idx < out.count else { break }
                out[idx] += rng.signed() * Float(exp(-Double(j) / sr * 30.0)) * r.amp * 0.5
            }
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            let s = lp2.tick(lp1.tick(rng.signed()))
            out[i] += s * max(0.3, 0.6 + pn1.sample(t: t, speed: sp1) * 0.25 + pn2.sample(t: t, speed: sp2) * 0.15) * 0.55
        }
    }

    // MARK: - 鸟鸣声（FM合成）
    private static func synBird(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let total = Double(out.count) / sr

        struct Call { var start, dur, freqStart, freqEnd, modRatio, modDepth: Double; var amp: Float }

        let birdCount = 3 + Int(rng.next() % 4)
        var allCalls: [Call] = []
        for _ in 0..<birdCount {
            let baseHz = rng.range(600, 1600)
            let birdAmp = Float(rng.range(0.05, 0.13))
            let mRatio = rng.range(1.2, 3.0)
            let mDepth = rng.range(30, 180)
            var ct = rng.range(0.3, 3.0)
            while ct < total - 1.0 {
                let groupSize = 1 + Int(rng.next() % 6)
                for gi in 0..<groupSize {
                    let dur = rng.range(0.04, 0.25)
                    let fStart = baseHz + Double(gi) * rng.range(10, 50)
                    allCalls.append(Call(start: ct, dur: dur, freqStart: fStart, freqEnd: fStart + rng.range(-500, 500), modRatio: mRatio + rng.range(-0.3, 0.3), modDepth: mDepth + rng.range(-30, 30), amp: birdAmp * Float(rng.range(0.7, 1.3))))
                    ct += dur + rng.range(0.02, 0.15)
                }
                ct += rng.range(1.0, 8.0)
            }
        }

        var bgLp1 = LP1(hz: 400, sr: Float(sr))
        var bgLp2 = LP1(hz: 200, sr: Float(sr))
        let pnBg = PerlinLFO(rng: &rng)
        let bgSp = rng.range(0.04, 0.12)
        var phases = [Double](repeating: 0, count: allCalls.count)
        var modPhases = [Double](repeating: 0, count: allCalls.count)
        let invSr = 1.0 / sr

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = bgLp2.tick(bgLp1.tick(rng.signed())) * 0.05 * max(0.2, 0.7 + pnBg.sample(t: t, speed: bgSp) * 0.25)
            for (ci, call) in allCalls.enumerated() {
                let rel = t - call.start
                guard rel >= 0 && rel < call.dur else { continue }
                let phase01 = rel / call.dur
                let env = Float(min(1.0, phase01 * 10.0) * (1.0 - phase01) * (1.0 - phase01))
                let carrFreq = call.freqStart + (call.freqEnd - call.freqStart) * phase01
                phases[ci] += (carrFreq + call.modDepth * Double(env) * sin(modPhases[ci] * .pi * 2)) * invSr
                modPhases[ci] += carrFreq * call.modRatio * invSr
                s += Float(sin(phases[ci] * .pi * 2)) * env * call.amp
            }
            out[i] = s
        }
    }

    // MARK: - 虫鸣声
    private static func synInsect(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let sid = sound.id
        if sid == "firefly" { synFirefly(&out, sr, &rng); return }

        let centerHz: Float = sid == "cricket" ? 2200 : 1800
        let bandwidth: Float = sid == "cricket" ? 350 : 500
        let chirpSpeed: Double = sid == "cricket" ? 14.0 : 8.0

        var lp = LP1(hz: centerHz + bandwidth * 0.5, sr: Float(sr))
        var hp = LP1(hz: max(100, centerHz - bandwidth * 0.5), sr: Float(sr))
        var bgLp = LP1(hz: 300, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let spAct = rng.range(0.08, 0.25)
        let spInt = rng.range(0.03, 0.1)

        var chirpEvents: [(start: Double, dur: Double)] = []
        if sid == "cricket" {
            var ct = rng.range(0.1, 0.8)
            let total = Double(out.count) / sr
            while ct < total - 0.5 {
                let burstDur = rng.range(0.2, 1.5)
                chirpEvents.append((ct, burstDur))
                ct += burstDur + rng.range(0.2, 3.5)
            }
        }

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = bgLp.tick(rng.signed()) * 0.02
            let raw = rng.signed()
            let filtered = lp.tick(raw) - hp.tick(raw)
            let am: Float
            if sid == "cricket" {
                var inChirp = false; var chirpPhase: Double = 0; var chirpDur: Double = 1
                for ev in chirpEvents {
                    let rel = t - ev.start
                    if rel >= 0 && rel < ev.dur { inChirp = true; chirpPhase = rel; chirpDur = ev.dur; break }
                }
                am = inChirp ? max(0.0, Float(sin(t * chirpSpeed * .pi * 2))) * Float(sin(chirpPhase / chirpDur * .pi)) : 0
            } else {
                am = max(0.0, Float(sin(t * chirpSpeed * .pi * 2))) * max(0.0, pn1.sample(t: t, speed: spAct) * 0.5 + 0.5)
            }
            s += filtered * am * max(0.0, 0.6 + pn2.sample(t: t, speed: spInt) * 0.35) * 0.2
            out[i] = s
        }
    }

    private static func synFirefly(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var bgLp1 = LP1(hz: 250, sr: Float(sr))
        var bgLp2 = LP1(hz: 120, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let bgSp = rng.range(0.04, 0.12)
        let brSp = rng.range(0.03, 0.08)

        struct FrogCall { var start, dur, freq: Double; var amp: Float }
        var frogs: [FrogCall] = []
        let frogCount = 2 + Int(rng.next() % 2)
        for fi in 0..<frogCount {
            let frogHz = rng.range(150, 380)
            let frogAmp = Float(rng.range(0.05, 0.13))
            var ft = rng.range(0.3, 2.0) + Double(fi) * rng.range(0.5, 1.5)
            let total = Double(out.count) / sr
            while ft < total - 0.5 {
                let dur = rng.range(0.1, 0.4)
                frogs.append(FrogCall(start: ft, dur: dur, freq: frogHz, amp: frogAmp))
                ft += dur + rng.range(0.8, 5.0)
            }
        }

        var sparkles: [(t: Double, dur: Double, hz: Double)] = []
        var st = rng.range(0.5, 3.5)
        let total = Double(out.count) / sr
        while st < total - 0.5 {
            sparkles.append((st, rng.range(0.06, 0.3), rng.range(1200, 2600)))
            st += rng.range(1.5, 8.0)
        }

        var sparkLp = LP1(hz: 2000, sr: Float(sr))
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = bgLp2.tick(bgLp1.tick(rng.signed())) * max(0.2, 0.7 + pn1.sample(t: t, speed: bgSp) * 0.2) * 0.15
            for frog in frogs {
                let rel = t - frog.start
                guard rel >= 0 && rel < frog.dur else { continue }
                s += Float(sin(t * frog.freq * .pi * 2)) * Float(sin(rel / frog.dur * .pi)) * frog.amp
            }
            for sp in sparkles {
                let rel = t - sp.t
                guard rel >= 0 && rel < sp.dur else { continue }
                sparkLp.a = LP1(hz: Float(sp.hz), sr: Float(sr)).a
                s += sparkLp.tick(rng.signed()) * Float(sin(rel / sp.dur * .pi)) * 0.04 * 3.0
            }
            out[i] = s * max(0.2, 0.6 + pn2.sample(t: t, speed: brSp) * 0.3)
        }
    }

    // MARK: - 火焰声
    private static func synFire(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let sid = sound.id
        var lpLo = LP1(hz: 200, sr: Float(sr))
        var lpLo2 = LP1(hz: 120, sr: Float(sr))
        var lpMid = LP1(hz: 700, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.06, 0.2)
        let sp2 = rng.range(0.02, 0.07)

        var pops: [(t: Double, amp: Float)] = []
        var pt: Double = rng.range(0.05, 0.5)
        let total = Double(out.count) / sr
        while pt < total {
            pops.append((pt, 0.08 + rng.f01() * 0.28))
            pt += rng.range(0.05, 0.9)
        }
        let gain: Float = sid == "candle" ? 0.25 : sid == "fireplace" ? 0.4 : 0.5

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lpLo2.tick(lpLo.tick(rng.signed())) * 0.3 + lpMid.tick(rng.signed()) * 0.12
            s *= max(0.3, 0.7 + pn1.sample(t: t, speed: sp1) * 0.18 + pn2.sample(t: t, speed: sp2) * 0.12)
            for pop in pops {
                let rel = t - pop.t
                guard rel >= 0 && rel < 0.025 else { continue }
                s += rng.signed() * Float(exp(-rel * 180)) * pop.amp
            }
            out[i] = s * gain
        }
    }

    // MARK: - 禅意声
    private static func synZen(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        switch sound.id {
        case "temple": synTemple(&out, sr, &rng)
        case "bell":   synBell(&out, sr, &rng)
        case "bowl":   synBowl(&out, sr, &rng)
        case "chime":  synChime(&out, sr, &rng)
        default:       synBowl(&out, sr, &rng)
        }
    }

    private static func synTemple(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let fund = 360.0
        let tempo = rng.range(0.8, 1.0)
        var hits: [(t: Double, amp: Float)] = []
        let total = Double(out.count) / sr
        var st = rng.range(0.2, 0.5)
        while st < total - 0.5 {
            hits.append((st, 0.50 + rng.f01() * 0.12))
            st += tempo * (0.92 + Double(rng.f01()) * 0.16)
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s: Float = 0
            for hit in hits {
                let rel = t - hit.t
                guard rel >= 0 && rel < 0.18 else { continue }
                let a = hit.amp
                s += Float(sin(rel * fund * .pi * 2)) * Float(exp(-rel * 22.0)) * a * 0.75
                s += Float(sin(rel * fund * 2.76 * .pi * 2)) * Float(exp(-rel * 40.0)) * a * 0.18
                s += Float(sin(rel * 1200.0 * .pi * 2)) * Float(exp(-rel * 90.0)) * a * 0.12
            }
            out[i] = s
        }
    }

    private static func synBell(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let fundCandidates: [Double] = [174.6, 196.0, 220.0, 246.9, 261.6]
        let partials: [(r: Double, a: Float, d: Double)] = [(1.0, 0.30, 0.15), (2.0, 0.18, 0.22), (2.76, 0.12, 0.3), (3.65, 0.08, 0.4), (4.72, 0.05, 0.55), (5.88, 0.03, 0.7)]
        var strikes: [(t: Double, amp: Float, fund: Double)] = []
        var st = rng.range(0.5, 2.0)
        let total = Double(out.count) / sr
        while st < total - 4.0 {
            let f = fundCandidates[Int(rng.next() % UInt64(fundCandidates.count))]
            strikes.append((st, 0.65 + rng.f01() * 0.35, f))
            st += rng.range(10.0, 22.0)
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s: Float = 0
            for strike in strikes {
                let rel = t - strike.t
                guard rel >= 0 && rel < 9.0 else { continue }
                for p in partials { s += Float(sin(t * strike.fund * p.r * .pi * 2)) * p.a * Float(exp(-rel * p.d)) * strike.amp }
            }
            out[i] = s
        }
    }

    private static func synBowl(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let fundCandidates: [Double] = [293.7, 329.6, 370.0, 396.0, 440.0, 493.9]
        let partials: [(r: Double, a: Float, d: Double)] = [(1.0, 0.35, 0.12), (2.71, 0.20, 0.18), (4.76, 0.10, 0.25), (7.03, 0.05, 0.35)]
        let tail = 25.0
        var strikes: [(t: Double, amp: Float, fund: Double)] = []
        var st = rng.range(0.5, 2.0)
        let total = Double(out.count) / sr
        while st < total - 5.0 {
            let f = fundCandidates[Int(rng.next() % UInt64(fundCandidates.count))]
            strikes.append((st, 0.8 + rng.f01() * 0.2, f))
            st += rng.range(18.0, 28.0)
        }
        let pn = PerlinLFO(rng: &rng)
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s: Float = 0
            for strike in strikes {
                let rel = t - strike.t
                guard rel >= 0 && rel < tail else { continue }
                let fade: Float = rel > tail - 2.0 ? Float((tail - rel) / 2.0) : 1.0
                for p in partials {
                    let drift = pn.sample(t: t, speed: 0.3) * 0.3
                    s += Float(sin(t * (strike.fund * p.r + Double(drift)) * .pi * 2)) * p.a * Float(exp(-rel * p.d)) * strike.amp * fade
                }
            }
            out[i] = s
        }
    }

    private static func synChime(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let notes: [Double] = [261.6, 293.7, 329.6, 392.0, 440.0, 523.25]
        var strikes: [(t: Double, hz: Double, amp: Float)] = []
        var st = rng.range(0.2, 1.0)
        let total = Double(out.count) / sr
        while st < total - 1.5 {
            strikes.append((st, notes[Int(rng.next() % UInt64(notes.count))], 0.08 + rng.f01() * 0.14))
            st += rng.range(0.3, 3.5)
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s: Float = 0
            for sk in strikes {
                let rel = t - sk.t
                guard rel >= 0 && rel < 2.5 else { continue }
                let env = Float(exp(-rel * 2.0))
                s += (Float(sin(t * sk.hz * .pi * 2)) + Float(sin(t * sk.hz * 2.003 * .pi * 2)) * 0.2) * env * sk.amp
            }
            out[i] = s
        }
    }

    // MARK: - 森林声
    private static func synForest(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        let sid = sound.id
        var lp1 = LP1(hz: 600, sr: Float(sr))
        var lp2 = LP1(hz: 300, sr: Float(sr))
        var lp3 = LP1(hz: 180, sr: Float(sr))
        var lpHi = LP1(hz: sid == "bamboo" ? 1000 : 550, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let pn3 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.05, 0.15)
        let sp2 = rng.range(0.12, 0.4)
        let sp3 = rng.range(0.02, 0.06)
        let hiMix: Float = sid == "bamboo" ? 0.2 : 0.08

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lp3.tick(lp2.tick(lp1.tick(rng.signed()))) * 0.3 + lpHi.tick(rng.signed()) * hiMix
            s *= max(Float(0.15), 0.5 + pn1.sample(t: t, speed: sp1) * 0.3 + pn2.sample(t: t, speed: sp2) * 0.15 + pn3.sample(t: t, speed: sp3) * 0.25)
            if sid == "leaves" { s += rng.signed() * max(0.0, pn1.sample(t: t, speed: 1.5) - 0.5) * 0.15 }
            out[i] = s * 0.5
        }
    }

    // MARK: - 氛围声
    private static func synAmbient(_ sound: SoundItem, _ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        switch sound.id {
        case "cave":   synCave(&out, sr, &rng)
        case "night":  synNight(&out, sr, &rng)
        case "garden": synGarden(&out, sr, &rng)
        default:       synNight(&out, sr, &rng)
        }
    }

    private static func synCave(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 150, sr: Float(sr))
        var lp2 = LP1(hz: 80, sr: Float(sr))
        let pn = PerlinLFO(rng: &rng)
        let spPn = rng.range(0.03, 0.1)
        let dlyN = Int(sr * 0.35)
        var dly = [Float](repeating: 0, count: dlyN)
        var di = 0

        var drips: [(t: Double, hz: Double, amp: Float)] = []
        var dt = rng.range(0.3, 2.0)
        let total = Double(out.count) / sr
        while dt < total - 0.5 {
            drips.append((dt, rng.range(350, 800), 0.06 + rng.f01() * 0.1))
            dt += rng.range(1.0, 6.0)
        }
        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lp2.tick(lp1.tick(rng.signed())) * 0.15 * max(0.2, 0.7 + pn.sample(t: t, speed: spPn) * 0.2)
            for d in drips {
                let rel = t - d.t
                guard rel >= 0 && rel < 0.1 else { continue }
                s += Float(sin(t * d.hz * .pi * 2)) * Float(exp(-rel * 40)) * d.amp
            }
            let delayed = dly[di]
            s += delayed * 0.4
            dly[di] = s * 0.45
            di = (di + 1) % dlyN
            out[i] = (s + Float(sin(t * 50 * .pi * 2)) * 0.04) * 0.5
        }
    }

    private static func synNight(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 80, sr: Float(sr))
        var lp2 = LP1(hz: 40, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let pn2 = PerlinLFO(rng: &rng)
        let sp1 = rng.range(0.015, 0.05)
        let sp2 = rng.range(0.4, 1.2)

        for i in 0..<out.count {
            let t = Double(i) / sr
            let base = lp2.tick(lp1.tick(rng.signed())) * 0.12
            let dMod: Float = 0.5 + pn1.sample(t: t, speed: sp1) * 0.4
            let d1 = Float(sin(t * 50 * .pi * 2)) * 0.03
            let d2 = Float(sin(t * 75 * .pi * 2)) * 0.02
            let distant = max(0.0, pn2.sample(t: t, speed: sp2) - 0.7) * 0.06
            out[i] = (base + (d1 + d2) * max(Float(0.1), dMod) + rng.signed() * distant) * 0.6
        }
    }

    private static func synGarden(_ out: inout [Float], _ sr: Double, _ rng: inout RNG) {
        var lp1 = LP1(hz: 400, sr: Float(sr))
        var lp2 = LP1(hz: 200, sr: Float(sr))
        let pn1 = PerlinLFO(rng: &rng)
        let spBg = rng.range(0.05, 0.15)

        var chirps: [(t: Double, hz: Double, dur: Double)] = []
        var ct = rng.range(0.3, 2.0)
        let total = Double(out.count) / sr
        while ct < total - 0.5 {
            chirps.append((ct, rng.range(450, 850), rng.range(0.06, 0.22)))
            ct += rng.range(1.0, 6.0)
        }
        var bLp = LP1(hz: 800, sr: Float(sr))
        var bBp = LP1(hz: 500, sr: Float(sr))

        for i in 0..<out.count {
            let t = Double(i) / sr
            var s = lp2.tick(lp1.tick(rng.signed())) * 0.1 * max(0.2, 0.7 + pn1.sample(t: t, speed: spBg) * 0.25)
            for ch in chirps {
                let rel = t - ch.t
                guard rel >= 0 && rel < ch.dur else { continue }
                bLp.a = LP1(hz: Float(ch.hz), sr: Float(sr)).a
                bBp.a = LP1(hz: Float(ch.hz * 0.7), sr: Float(sr)).a
                s += bBp.tick(bLp.tick(rng.signed())) * Float(sin(rel / ch.dur * .pi)) * 0.04 * 4.0
            }
            out[i] = s
        }
    }
}
