# 登山記録Markdown拡張フォーマット 実装方針・Claude Code向け指示

## プロジェクト概要

日本の登山記録は現在、YAMAPやヤマレコのような中央集権型サービスに集まりがちだが、本プロジェクトでは「各人が自分のブログや個人サイトに自由に登山記録を書き、それを機械的にも扱える」仕組みを目指す。

新しいSNSや投稿サービスを作ることが目的ではない。

目標は、

- 記録の正本は各ユーザーのMarkdown・ブログ・個人サイトに置く
- Markdownは通常の文章として読める
- 必要な箇所だけ構造化できる
- GPXなど既存のオープン形式と組み合わせる
- 将来的に複数の検索サービス・地図サービスなどから収集できる
- 特定サービスへのロックインを避ける

という分散型の登山記録フォーマットを作ること。

---

## 基本思想

既存規格をできるだけ活用する。

想定する役割分担は以下。

- Markdown
  - 山行本文
  - 写真
  - 通常の見出しやリンク
- YAML Front Matter
  - 山行全体のメタデータ
- 独自Markdown拡張
  - 本文中の地点・危険情報・登山道状況など
- GPX
  - 実際に歩いた軌跡
- 将来的には
  - GeoJSON
  - RSS / Atom / GeoRSS
  - OpenStreetMap / Wikidata ID
  - HTML上の構造化データ

などへの展開を想定する。

Markdown独自記法を増やしすぎず、「普通のMarkdown + 最小限の拡張」にする。

---

## 採用する記法の方向性

### 1. YAML Front Matter

文書全体のメタデータに使用する。

例:

```markdown
---
type: hike
title: 雲取山を三峰から縦走
started_at: 2026-07-10T06:20:00+09:00
ended_at: 2026-07-10T17:40:00+09:00

track:
  url: ./track.gpx

stats:
  distance_m: 21300
  ascent_m: 1780

tags:
  - 奥多摩
  - 雲取山
---

本文……
```

YAMLは完全なYAML仕様を必須にせず、必要ならサポートするサブセットを限定してよい。

### 2. 通常本文

CommonMarkを基本とする。

可能な限り独自記法がなくても通常のMarkdownレンダラーで読める状態を維持する。

GFM相当の以下の記法は必要に応じて利用可。

- table
- task list
- footnote
- strikethrough

ただしこれらを登山記録の構造化データの正本にはしない。

### 3. 独自ブロック

本文中で構造化したい情報には、Pandoc / remark / MyST系に近いDirective / Fenced Div形式を使いたい。

現時点の案:

```markdown
:::hazard{severity="warning" lat="35.87" lon="138.94"}
登山道を塞ぐ倒木あり。右側から迂回可能。
:::
```

例として以下のblock typeを検討する。

```text
waypoint
hazard
trail-condition
water-source
transport
```

v0.1では種類を増やしすぎないこと。

候補としてまず以下の3つ程度でもよい。

```text
waypoint
hazard
trail-condition
```

本文内部には通常のMarkdownを記述可能にする。

---

## 最重要の設計方針

Markdownから直接HTMLに変換する実装にはしない。

必ず中間表現として型付きAST / データモデルを持つ。

処理系は概ね以下。

```text
Markdown source
      ↓
Front Matter split
      ↓
Markdown parser
      ↓
独自Directive parser
      ↓
Normalized Hike AST
      ├─ Validator
      ├─ HTML renderer
      ├─ JSON exporter
      ├─ GeoJSON exporter
      └─ 将来のRSS / indexer等
```

HTMLは出力形式の一つにすぎない。

---

## MoonBitで実装する

実装言語はMoonBit。

このプロジェクトでは特に、

- 型付きAST
- enumによる値制約
- CLI
- nativeビルド
- 将来的なWasm利用
- snapshot test

との相性を期待している。

例えば概念上のASTは以下のようになる。

```moonbit
enum HikeBlock {
  Markdown(...)
  Waypoint(Waypoint)
  Hazard(Hazard)
  TrailCondition(TrailCondition)
}

enum Severity {
  Info
  Caution
  Warning
  Danger
}

struct GeoPoint {
  latitude : Double
  longitude : Double
}

struct Hazard {
  severity : Severity
  observed_at : DateTime?
  location : GeoPoint?
  children : Array[HikeBlock]
}
```

実際の型名や構造は既存Markdown ASTとの統合方法を調査したうえで設計すること。

---

## Markdownパーサーについて

MoonBitの既存Markdownライブラリをまず調査して利用する。

候補としては、

- moonbit-community/cmark
- markdown.mbt

などがある。

仕様のリファレンス実装としては、CommonMark互換性を優先する。

ただし既存Markdownライブラリ本体へ独自Directiveを深くパッチする設計は避けたい。

例えば、

```text
source
 ↓
独自block scanner
 ↓
通常Markdown部分 → CommonMark parser
独自Directive    → custom Hike AST node
```

のような薄い拡張レイヤーを優先して検討する。

Markdownライブラリ側に自然な拡張APIがあるなら、それを使ってよい。

---

## 実装すべき主要コンポーネント

### 1. Parser

Markdown sourceから以下を抽出する。

- Front Matter
- 通常Markdown
- 独自Directive
- Directive attributes
- Directive body

可能ならsource positionも保持する。

例:

```text
line
column
start offset
end offset
```

バリデーションエラーを元ファイルの位置へ返すために必要。

### 2. Normalized AST

Markdownライブラリ固有ASTをそのまま公開APIにしない。

本プロジェクト固有の正規化された型を定義する。

例えば、

```text
HikeDocument
HikeMetadata
HikeBlock
Waypoint
Hazard
TrailCondition
Location
Severity
```

など。

将来的に別Markdown parserへ切り替えても、Hike AST以降は変更しなくて済む構造にする。

### 3. Validator

少なくとも以下の2種類を分ける。

#### Syntax validation

例:

- Directiveが閉じられていない
- 属性記法が不正
- 属性値が壊れている
- 許可されていないnest
- Front Matterが壊れている

#### Semantic validation

例:

- severityの値が不正
- latitudeが -90〜90 外
- longitudeが -180〜180 外
- started_at > ended_at
- distanceが負
- 必須属性が不足
- 同一属性の重複

エラー形式はCLI・エディタの双方で利用可能にしたい。

例:

```text
hike.md:42:18
error: severity must be one of: info, caution, warning, danger
```

内部的には構造化されたDiagnostic型を持つ。

例:

```text
severity
code
message
source range
suggestion
```

### 4. HTML renderer

Hike ASTからHTMLへ変換する。

HTMLは単なる見た目ではなく意味をできるだけ保持する。

例えば:

```html
<section
  class="hike-hazard"
  data-severity="warning"
  data-lat="35.87"
  data-lon="138.94"
>
  <p>登山道を塞ぐ倒木あり。</p>
</section>
```

要件:

- JavaScriptなしでも内容が読める
- semantic HTMLを優先
- data-* に機械可読情報を残せる
- CSSがなくても文章として成立する
- HTML escapeを確実に行う

将来的にJSON-LD等を載せる余地を残す。

### 5. Default CSS

最小限の標準CSSを提供する。

ただしCSSは仕様の必須部分にしない。

考慮事項:

- light / dark mode
- print
- accessibility
- CSS custom properties
- class名の安定性

利用者が独自CSSへ差し替えられるようにする。

### 6. JSON exporter

Hike ASTをJSONとして出力可能にする。

デバッグ、検索インデックス、他言語連携の基礎として重要。

例:

```json
{
  "type": "hazard",
  "severity": "warning",
  "location": {
    "latitude": 35.87,
    "longitude": 138.94
  }
}
```

JSON表現はなるべく安定した公開形式として設計する。

### 7. GeoJSON exporter

v0.1必須でなくてもよいが、設計上は考慮する。

例えば、

- waypoint → Point
- hazard → Point
- GPX route → LineString

などに変換可能にする。

---

## CLI

CLIを最初の主要インターフェースとする。

仮のコマンド名は自由に決めてよい。

最低限以下を想定。

```bash
hikelog validate hike.md
hikelog render hike.md
hikelog render hike.md -o hike.html
hikelog dump hike.md
hikelog export hike.md --format json
```

候補:

```text
validate
render
dump
export
```

余裕があれば、

```text
format
fix
```

も検討する。

終了コードもCIで利用しやすくする。

---

## Test

仕様と実装の双方を守るため、テストケースを重要視する。

以下のような構成を想定。

```text
tests/
  valid/
    minimal.md
    complete.md
    hazard.md
    nested-markdown.md

  invalid/
    invalid-severity.md
    invalid-latitude.md
    unclosed-directive.md

  expected/
    minimal.ast.json
    minimal.html
```

特にsnapshot testを積極的に使う。

検証対象:

- AST
- diagnostics
- HTML
- JSON

境界値と異常系を十分用意する。

---

## フォールバック性を重視する

独自Markdown拡張は、未対応環境で完全に意味不明になる設計を避ける。

理想としては、

- 本文そのものは普通に読める
- 独自属性が無視されても情報の大半は残る
- GPX等の添付ファイルは通常リンクとして辿れる

状態にする。

その意味でMDXのような、

```mdx
<Hazard severity="warning">
...
</Hazard>
```

形式は今回の交換フォーマットの中心には使わない。

---

## GPX

GPXは独自仕様へ内包しない。

既存GPXファイルを参照する。

例:

```yaml
track:
  url: ./track.gpx
```

将来的には、

- file existence
- GPX parse
- 山行日時との整合性
- 距離や標高差の算出
- metadataとの差分確認

などをvalidatorの追加機能として実装できる。

v0.1では必須ではない。

---

## Front Matterと本文Directiveの責務

文書全体に一つしかない情報はFront Matter。

例:

```text
title
started_at
ended_at
activity type
track
distance
ascent
members
license
```

本文の特定位置・時点に紐づく情報はDirective。

例:

```text
waypoint
hazard
trail condition
water source
```

同じ情報を両方に持たせないようにする。

---

## バージョニング

仕様自体にversionを持たせることを検討する。

例えば:

```yaml
---
format: open-hike
format_version: 0.1
---
```

名称は未定。

後方互換性を保つため、v0.1段階からversionの扱いだけは決めておきたい。

---

## 今回まだ決めきっていない論点

以下は実装しながら検討し、勝手に大きな仕様判断を確定させず、READMEまたは設計メモに選択肢と推奨案を書くこと。

### Directive syntax

候補:

```markdown
:::hazard{severity="warning"}
...
:::
```

または属性を別行にする方式など。

既存Markdownエコシステムとの互換性を調査し、最も自然な方式を提案する。

### Directive nesting

例えば、

```text
waypoint
 └ hazard
```

を許すべきか。

v0.1では禁止または限定する方がシンプルかもしれない。

### 属性値の型

Directiveの属性を全て文字列としてparse後に型変換するか、parser段階で型を持たせるか。

Parserとsemantic validatorの責務を分離したい。

### DateTime

ISO 8601 / RFC 3339相当を基本にしたい。

Timezoneを必須にするか検討する。

登山記録ではtimezoneを曖昧にしない方が望ましい。

### location

緯度経度を、

```text
lat
lon
```

とするか、

```text
latitude
longitude
```

とするか。

公開仕様なので短さより可読性を優先してよい。

### elevation

単位をキー名に含め、

```text
elevation_m
```

とする方式を優先候補とする。

distance等も同様。

### severity

候補:

```text
info
caution
warning
danger
```

意味の境界を仕様書で定義する必要がある。

### 未知属性

未知属性を、

- error
- warning
- preserve

のどれにするか。

将来拡張性を考えるとpreserve + warningが候補。

### 未知Directive

知らないDirectiveをどう扱うか。

将来互換性を考えると、

- AST上はUnknownDirectiveとして保持
- HTMLでは通常のdiv相当として本文を残す
- validatorではwarning

などが候補。

### YAMLの仕様範囲

完全なYAML 1.2を要求する必要はない。

利用するMoonBit YAMLライブラリで安全・安定して扱えるサブセットを確認し、その範囲を仕様化する案を検討する。

---

## v0.1の実装スコープ

まずは小さく完成させる。

必須:

```text
- CommonMark本文
- YAML Front Matter
- HikeDocument AST
- :::waypoint
- :::hazard
- :::trail-condition
- attributes parser
- validator
- HTML renderer
- JSON dump/export
- CLI
- tests
```

v0.1では後回しでよい:

```text
- GPX解析
- GeoJSON
- RSS / Atom
- GeoRSS
- OSM連携
- Wikidata連携
- 地図UI
- JavaScript UI
- VS Code extension
- Language Server
- 検索エンジン
```

---

## 初回タスク

まずコードを書き始める前に、以下を行うこと。

1. 現在のMoonBit環境と利用可能なMarkdown / YAMLライブラリを確認する
2. CommonMark parser候補を比較する
3. 独自Directiveを実装する方法を調査する
4. 推奨アーキテクチャを書く
5. 最小のAST案を書く
6. Directive syntax案を書く
7. ディレクトリ構成を提案する
8. その後、v0.1の最小vertical sliceを実装する

最初のvertical sliceは例えば以下。

```markdown
---
title: Test hike
---

# Test hike

:::hazard{severity="warning" latitude="35.0" longitude="139.0"}
倒木あり。
:::
```

これを、

```text
parse
→ Hike AST
→ validate
→ JSON dump
→ HTML render
```

まで通す。

その後テストを増やしながら機能を拡張する。

---

## 実装上の方針

- class/decorator的な複雑な設計は避ける
- 小さい関数と明確な型を優先
- parser / model / validator / rendererの責務を分ける
- Markdownライブラリ固有型を外部APIへ漏らしすぎない
- 独自DSLを過度に複雑化しない
- premature abstractionを避ける
- 仕様上の曖昧さはコードに埋め込まず設計メモに残す
- public APIにはテストを付ける
- エラーメッセージのsource locationを重視する
- HTML rendererとvalidatorを密結合させない
- 将来的なWasm利用を妨げるOS依存をcore packageへ入れない

---

## このプロジェクトの成功条件

v0.1では、

```text
1つのMarkdownファイルを書けば
↓
通常のMarkdownとして人間が読めて
↓
CLIで構文・意味を検証できて
↓
構造化JSONへ変換できて
↓
意味を保持したHTMLへ変換できる
```

ところまで到達すればよい。

YAMAPやヤマレコの代替サービスを作る必要はない。

まず「個人サイトに置ける、オープンで機械可読な登山記録Markdown」を成立させることを最優先とする。
