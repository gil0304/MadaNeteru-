//
//  BatteryMonitor.swift
//  MadaNeteru?
//
//  要件 11章。UIDevice のバッテリー監視を有効にし、充電状態を取得する。
//  「充電済みと確認できた時だけ鳴らさない」判定の入力を提供する。
//

import Foundation
import SwiftUI
import UIKit
import Combine

@MainActor
@Observable
final class BatteryMonitor {
    private(set) var state: BatteryStateKind = .notChecked
    private(set) var level: Double = -1
    // deinit（非分離）からも解除できるよう非分離で保持。書き込みは init 時のみ。
    nonisolated private let observerBox = ObserverBox()

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        observe()
    }

    /// 現在値を読み直す。要件 6.4 同様、フォア復帰時などに呼ぶ。
    func refresh() {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        state = Self.map(device.batteryState)
        let lvl = Double(device.batteryLevel)
        level = lvl < 0 ? -1 : lvl
    }

    /// 充電済みと確認できたか（鳴らさない条件）。
    var isConfirmedCharged: Bool { state.isConfirmedCharged }

    private func observe() {
        let center = NotificationCenter.default
        let stateObs = center.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let levelObs = center.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        observerBox.tokens = [stateObs, levelObs]
    }

    deinit {
        observerBox.removeAll()
    }

    private static func map(_ s: UIDevice.BatteryState) -> BatteryStateKind {
        switch s {
        case .charging:  return .charging
        case .full:      return .full
        case .unplugged: return .unplugged
        case .unknown:   return .unknown
        @unknown default: return .unknown
        }
    }
}

/// NotificationCenter のトークンを deinit からも安全に解除するための入れ物。
nonisolated private final class ObserverBox: @unchecked Sendable {
    var tokens: [NSObjectProtocol] = []
    func removeAll() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }
}
