# まだ寝てる? (MadaNeteru?)

Googleカレンダー連動型の **“寝坊・充電忘れ防止アラーム”** — iOS 26 / SwiftUI / AlarmKit。

予定管理アプリではなく、**「明日の予定に遅れない状態を、前日の夜に自動で整える」** アプリ。
Googleカレンダーの予定をもとに、起床アラーム・予定前アラーム・夜の充電確認を自動で準備する。

> 📖 **ドキュメント**
> - [docs/使い方.md](docs/使い方.md) … アプリの使い方（利用者向け）
> - [docs/カスタマイズ.md](docs/カスタマイズ.md) … 文言・キャラ配置・色の変え方（開発者向け）

---

## 動作要件

- Xcode 26 / iOS 26 SDK
- iOS 26 以上の実機またはシミュレータ
- ターゲット: `MadaNeteru?`（Bundle ID: `app.Ochiai.gil.MadaNeteru-`）

## ビルド & 実行

```sh
# シミュレータ（iPhone 17 Pro など iOS 26）
xcodebuild -project "MadaNeteru?.xcodeproj" -scheme "MadaNeteru?" \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build

# 開発用デモ起動（オンボーディングを飛ばしモックログイン+同期、DEBUG限定）
xcrun simctl launch <SIM_UDID> app.Ochiai.gil.MadaNeteru- -demoMode
#   -demoTab 0|1|2     ホーム/予定/ルール のいずれかで起動
```

> Xcode の `Run` でもそのまま起動できる。初回はオンボーディングが表示される。

---

## アーキテクチャ

```
MadaNeteru?/
├─ Models/         SwiftData @Model（要件14章の6モデル）+ Enums
├─ Services/       ドメインサービス（すべてプロトコルで抽象化）
├─ Stores/         AppModel（中央コーディネータ）, SettingsStore
├─ Views/          画面（デザイン v4・3タブ）: Onboarding / Home / Events / Rules
│                  ＋ EventDetail / WeekdayRules / DefaultSettings / ChargeAlarm
└─ Support/        Theme・日付ヘルパ・Color拡張・Preview用ファクトリ
```

`PBXFileSystemSynchronizedRootGroup` 方式のため、`MadaNeteru?/` 配下に置いた
`.swift` は自動でビルド対象になる（pbxproj の手編集不要）。

### レイヤーの考え方

| 関心事 | 抽象 | 実装 |
|---|---|---|
| アラーム発火 | `AlarmScheduling` | `AlarmKitScheduler`（実AlarmKit） / `MockAlarmScheduler` |
| 軽い通知 | — | `NotificationService`（UNUserNotifications） |
| カレンダー同期 | `CalendarSyncService` | `MockCalendarProvider`（既定） / `GoogleCalendarProvider`（実装シーム） |
| 充電状態 | — | `BatteryMonitor`（UIDevice バッテリー監視） |
| ルール解決 | — | `AlarmRuleResolver`（純粋関数 / 優先順位） |
| アラーム計画 | — | `AlarmPlanner`（予定+ルール → PlannedAlarm 群） |

### ルールの優先順位（要件8章）

```
予定ごと(event) > 曜日ごと(weekday) > 全体デフォルト(global)
```

`AlarmRuleResolver` が種別ごとに 1 か所で解決する。予定/曜日ティアに
「無効化ルール(isEnabled=false)」があると、その種別は下位を上書きして
“鳴らさない”（＝この予定だけアラーム不要 / 要件13.4）。
全体デフォルトは `AlarmRule` 行ではなく `SettingsStore`（`GlobalDefaults`）由来。

### 充電確認（要件11章）

`UIDevice` のバッテリー監視で `charging / full / unplugged / unknown` を取得。
**充電済み（charging/full）と確認できた場合だけ鳴らさない**。`unknown`・未確認は
安全側に倒してアラームを鳴らす（要件11.3）。

### AlarmKit と通常通知の使い分け（要件12章）

- AlarmKit: 起床 / 充電確認 / 出発 / 未設定警告（長時間・強く鳴らす）
- 通常通知: 予定リマインドなど軽いもの
- AlarmKit が未認可・失敗時は通常通知へ自動フォールバックし、画面に警告を出す（要件17.1）

---

## 実 Google 連携（OAuth 2.0 / PKCE 実装済み）

実連携は **外部 SDK なし**で実装済み（`ASWebAuthenticationSession` + PKCE + `URLSession`）。
クライアントID を入れるだけで有効化され、未設定なら自動で `MockCalendarProvider` に
フォールバックする（`MadaNeteru_App.swift` の `RootContainer`）。

1. Google Cloud Console で **iOS の OAuth 2.0 クライアントID** を発行
   - Calendar API を有効化、Bundle ID `app.Ochiai.gil.MadaNeteru-`
   - スコープ `https://www.googleapis.com/auth/calendar.readonly`（読み取りのみ）
2. `Services/Google/GoogleConfig.swift` の `clientID` に貼る（例 `…….apps.googleusercontent.com`）

これだけで `GoogleCalendarProvider` が有効化される。実装の中身:

- 認証: `GoogleAuthService`（同意 → コード交換 → アクセス/リフレッシュトークン、Keychain 保存、自動リフレッシュ）
- 同期: `events.list`（初回 `timeMin/timeMax`、2回目以降 `syncToken`、`410 GONE` で full sync 再試行、ページング、終日/時刻あり判定）
- コールバックは reversed client ID スキームを使う。`Info.plist` に同じ URL Type を登録しておく必要がある

`CalendarSyncService` プロトコルだけに依存するため、画面・ロジックは変更不要。

## バックグラウンド更新（BGTaskScheduler 実装済み）

`BackgroundRefreshController` が `BGAppRefreshTask`（ID `app.Ochiai.gil.MadaNeteru.refresh`）
を登録・予約し、アプリ未起動時もシステムが許す範囲で `backgroundRefresh()` を実行する:
カレンダー同期 → アラーム再構築（未設定の再評価込み）→ **充電済みなら今夜の充電アラームを自動停止**（要件 11.1）。

- `Info.plist`: `UIBackgroundModes = [fetch]`、`BGTaskSchedulerPermittedIdentifiers`（設定済み）
- 予約タイミング: 起動時・バックグラウンド遷移時・各実行の完了時
- フォアグラウンド復帰時も同期＋充電自動確認を実行（即時の補完）
- **実機での発火テスト**: デバッガを一時停止して
  `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"app.Ochiai.gil.MadaNeteru.refresh"]`
  を実行（システムの実スケジュールは数時間〜の間隔で OS 判断）。

> 注: iOS は「毎日 20:00 ちょうど」のような厳密時刻の背景実行は許可しない。
> 厳密時刻が要る未設定警告・充電確認・起床は **AlarmKit の確定スケジュール**で鳴らし、
> バックグラウンド更新は予定変更の追従と自動停止に使う、という役割分担にしている。

## 実機での AlarmKit 確認

- AlarmKit の認可には `Info.plist` の `NSAlarmKitUsageDescription` が必要（設定済み）。
- ロック画面 / Dynamic Island のカウントダウン Live Activity を完全表示するには、
  `AlarmAttributes<MadaNeteruMetadata>` 対応の **Widget Extension** を追加する
  （今回のスコープ外。本体のスケジュールとアラート提示までは動作）。

---

## デザイン（ハイファイ v4）

「まだねてる？ ハイファイ v4」に沿って実装。iOS標準のインセットリストを基調に、
オレンジ(#EE5A24)アクセント＋キャラクターの吹き出しで「話しかけてくる」トーン。

- **3タブ**: ホーム / 予定 / ルール（履歴・設定タブは無し）
  - ホーム: 夜→朝のヒーローグラデ＋キャラ＋「今夜のチェック」
  - 予定: 明日/今日/7日間セグメント＋予定行（起床/出発/🔋バッジ）→ 予定詳細
  - ルール: 適用ルール（個別＞曜日＞デフォルトの色バッジ）→ 曜日ルール / デフォルト設定
  - 充電確認アラーム鳴動画面（アプリ内フルスクリーン）
- **キャラクター画像を実装済み**（`Assets.xcassets/char-*.imageset`）。ユウチャ/アイウエオ/
  シロ/ワタミ/ギル/エミリー/カミム/ホノピの8体を `CharacterView`（`DesignKit.swift`）が表示。
  差し替えは各 imageset の PNG を置き換えるだけ。画面ごとの割り当て・入れ替え方は
  [docs/カスタマイズ.md](docs/カスタマイズ.md) を参照。
- デザイントークンは `Support/Theme.swift`、共通UI部品は `Views/Components/DesignKit.swift`。

## データモデル（要件14章）

`AppUser` / `CalendarEvent` / `AlarmRule` / `ScheduledAlarm` / `ChargeCheck` /
`CalendarSyncState` を SwiftData で永続化。MVP は端末内保存（プライバシー要件17.2）。

## MVP 実装状況

要件16章の MVP 必須項目（Googleログイン・同期・明日の予定・AlarmKit権限・
予定/曜日/全体のアラーム設定・未設定チェック・起床/充電確認アラーム・スヌーズ・
履歴・充電確認済みボタン）を実装済み。実 Google OAuth 連携（PKCE）と
バックグラウンド更新（BGTaskScheduler）も実装済み。`clientID` 未設定時のみモックで動作。
スコープ外: Live Activity 用 Widget Extension。
