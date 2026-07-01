//
//  DesignKit.swift
//  MadaNeteru?
//
//  「まだねてる？ ハイファイ v4」の共通UI部品。
//  iOS標準のインセットリスト＋キャラクター吹き出しを再現する。
//

import SwiftUI

/// 色付きインライン文字列を AttributedString で組む（iOS26 で Text 同士の `+` が非推奨）。
/// 親 View 側で .font / .foregroundStyle を付けると、色未指定の部分に継承される。
func styledText(_ segments: [(String, Color?)]) -> Text {
    var attr = AttributedString()
    for (str, color) in segments {
        var piece = AttributedString(str)
        if let color { piece.foregroundColor = color }
        attr.append(piece)
    }
    return Text(attr)
}

// MARK: - ルールの出どころ（個別 > 曜日 > デフォルト）

enum RuleTier {
    case individual, weekday, defaults
    var label: String {
        switch self {
        case .individual: return "個別"
        case .weekday:    return "曜日"
        case .defaults:   return "デフォルト"
        }
    }
    var color: Color {
        switch self {
        case .individual: return Theme.red
        case .weekday:    return Theme.orange
        case .defaults:   return Theme.secondary
        }
    }
}

struct SourceBadge: View {
    let tier: RuleTier
    var body: some View {
        Text(tier.label)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 1.5)
            .background(tier.color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

// MARK: - アイコン（角丸＋絵文字）

struct AlarmTypeIcon: View {
    let type: AlarmType
    var size: CGFloat = 30
    var body: some View {
        EmojiIcon(emoji: type.emoji, color: Theme.color(for: type), size: size)
    }
}

struct EmojiIcon: View {
    let emoji: String
    let color: Color
    var size: CGFloat = 28
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Text(emoji).font(.system(size: size * 0.52)))
    }
}

// MARK: - セクション見出し / カード / 行区切り

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}

/// 白の角丸インセットカード。中に行を並べ、間に `RowSeparator()` を挟む。
struct InsetCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct RowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, 15)
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.chevron)
    }
}

// MARK: - キャラクター
//
// ▼ キャラの入れ替え方
//   ・画像を差し替える : Assets.xcassets/<名前>.imageset の PNG を置き換える
//   ・画面のキャラを変える: 各画面で CharacterView(character: .xxx) の .xxx を変更する
//                          （例: HomeView は .shiro、RulesView は .gil）
// ▼ 新キャラを足す
//   ・Assets に <新名>.imageset を追加 → 下の enum に case を1つ足すだけ
//
enum AppCharacter: String {
    case yucha, aiueo, shiro, watami, gil, emily, kamimu, honopi, undefined

    /// 新しいステッカー風アセット名を優先し、旧 char- 系もフォールバックで許容する。
    var assetNames: [String] {
        guard self != .undefined else { return [] }
        return [rawValue, "char-\(rawValue)"]
    }

    var displayName: String {
        switch self {
        case .yucha:     return "ユウチャ"
        case .aiueo:     return "アイウエオ"
        case .shiro:     return "シロ"
        case .watami:    return "ワタミ"
        case .gil:       return "ギル"
        case .emily:     return "エミリー"
        case .kamimu:    return "カミム"
        case .honopi:    return "ホノピ"
        case .undefined: return "未定"
        }
    }
}

/// キャラ画像を指定の高さで表示する。画像は透明PNGをそのまま（背景を足さない）。
/// アセット未登録／未定キャラは破線プレースホルダを表示。
struct CharacterView: View {
    var character: AppCharacter
    var height: CGFloat
    var onDark: Bool = false

    var body: some View {
        if let name = character.assetNames.first(where: { UIImage(named: $0) != nil }),
           let ui = UIImage(named: name) {
            characterImage(uiImage: ui, assetName: name)
        } else {
            placeholder
                .frame(width: height * 0.86, height: height)
        }
    }

    @ViewBuilder
    private func characterImage(uiImage: UIImage, assetName: String) -> some View {
        let image = Image(uiImage: uiImage)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: height * 0.86, height: height)

        if assetName.hasPrefix("char-") {
            // 旧 char- 系は半透明が強いので、従来どおり白プレート付きで表示する。
            image
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: height * 0.12, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 3, y: 1)
        } else {
            // 新しいステッカー風画像はそのまま見せる。
            image
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(onDark ? Color.white.opacity(0.12) : Theme.groupedBg)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    .foregroundStyle(onDark ? Color.white.opacity(0.45) : Theme.chevron)
            )
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.system(size: height * 0.22))
                    Text(character.displayName).font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(onDark ? Color.white.opacity(0.6) : Theme.secondary)
            )
    }
}

// MARK: - 吹き出し

enum BubbleTail { case bottomLeading, bottomCenter, leading, none }

struct SpeechBubble<Content: View>: View {
    var tail: BubbleTail = .bottomLeading
    var bg: Color = .white
    var radius: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(bg, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(alignment: alignment) { tailShape }
    }

    private var alignment: Alignment {
        switch tail {
        case .bottomLeading: return .bottomLeading
        case .bottomCenter:  return .bottom
        case .leading:       return .leading
        case .none:          return .center
        }
    }

    @ViewBuilder private var tailShape: some View {
        if tail != .none {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(bg)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))
                .offset(x: tailOffset.x, y: tailOffset.y)
        }
    }

    private var tailOffset: (x: CGFloat, y: CGFloat) {
        switch tail {
        case .bottomLeading: return (20, 6)
        case .bottomCenter:  return (0, 6)
        case .leading:       return (-6, 0)
        case .none:          return (0, 0)
        }
    }
}

// MARK: - 曜日サークル

struct DayCircle: View {
    let label: String
    var selected: Bool
    var textColor: Color = Theme.label
    var size: CGFloat = 46
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? .white : textColor)
                .frame(width: size, height: size)   // 明確な円のサイズ＋内側余白
                .background(selected ? Theme.orange : Theme.card, in: Circle())
                .overlay(
                    Circle().strokeBorder(selected ? Color.clear : Theme.separator, lineWidth: 1)
                )
                .shadow(color: .black.opacity(selected ? 0 : 0.06), radius: 2, y: 1)
                .frame(maxWidth: .infinity)          // 均等配置（円の間に余白）
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 角丸オレンジボタン

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(enabled ? Theme.orange : Theme.secondary,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
