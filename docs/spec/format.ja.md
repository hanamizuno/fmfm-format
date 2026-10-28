# fmfm フォーマット仕様 — ドラフト v0.1

> 状態: **ドラフト**。本書はフォーマットの規範的な記述です。英語版 [format.md](format.md) が正本で、本書はその日本語訳です。設計理由は `docs/knowledge/adr/` の ADR にあります。

fmfm は登山(および類似のアウトドア活動)記録のための Markdown ベースのファイル形式です。ファイルは任意の Markdown レンダラーで表示できる普通の CommonMark に、次の小さな省略可能な構造を 2 層重ねたものです。

1. 文書全体のメタデータを持つ **YAML Front Matter**
2. 本文中の地点 — 通過点、危険箇所、登山道状況 — を機械可読な属性付きで示す **ディレクティブ**(`:::name{…}` … `:::`)

記録の正本は著者が公開している場所(ブログ、静的サイト、git リポジトリ)に置かれたままです。ツールはそれを読むだけで、所有しません。

## 1. 文書

文書は UTF-8 のテキストファイルで、慣例として `*.md` です。省略可能な Front Matter ブロックと、それに続く本文からなります。

```markdown
---
format: fmfm
format_version: "0.1"
title: 雲取山を三峰から縦走
started_at: 2026-07-10T06:20:00+09:00
ended_at: 2026-07-10T17:40:00+09:00
track:
  url: ./track.gpx
stats:
  distance_m: 21300
  ascent_m: 1780
tags: [奥多摩, 雲取山]
---

# 雲取山縦走

06:20 に三峯神社を出発……

:::hazard{severity="warning" latitude="35.87" longitude="138.94"}
白岩小屋の少し下で倒木が登山道を塞いでいる。右側から迂回可能。
:::
```

改行は LF と CRLF のどちらでもよく、UTF-8 の BOM は無視されます。

## 2. Front Matter

ファイルの **1 行目** がちょうど `---` のとき Front Matter が存在します。次にちょうど `---` または `...` となる行で終わります。その間の行が YAML(下記サブセット)です。`---` で始まらないファイルには Front Matter がありません。

### 2.1 許容する YAML サブセット

* 1 文書のみ
* ブロックマッピング(`key: value`)とブロックシーケンス(`- item`)。インデントによるネスト可
* プレーン、単引用、二重引用のスカラー。リテラル(`|`)と折り畳み(`>`)ブロックスカラー
* コメント(`# …`)

許容しないもの(構文エラー): アンカーとエイリアス、タグ(`!!str`)、フロー形式のコレクション(`{…}`, `[…]`)。ただし `tags: [a, b]` のようなスカラーのみの平坦なシーケンスは例外として許容。複数文書、スカラー以外のキー、重複キー。

構文レベルではすべてのスカラーは文字列です。その解釈(整数、小数、日時など)は後述の各フィールドで定義します。

### 2.2 フィールド

| キー | 型 | 必須 | 意味 |
| --- | --- | --- | --- |
| `format` | 文字列。`fmfm` 固定 | 推奨 | ファイルが fmfm 文書であることを示す。欠落 → 警告 `missing-format`。他の値 → エラー `invalid-format`。 |
| `format_version` | 文字列 `MAJOR.MINOR` | 推奨 | 文書が対象とする本仕様のバージョン。欠落 → 警告。未知のメジャーバージョン → エラー。YAML リーダーが数値化しないよう引用符で囲む(`"0.1"`)。 |
| `type` | 文字列 | 任意 | 活動種別。v0.1 では `hike`(既定値)のみ定義。 |
| `title` | 文字列 | **必須** | 記録のタイトル。 |
| `started_at` | 日時 | 任意 | 活動の開始時刻。 |
| `ended_at` | 日時 | 任意 | 終了時刻。`started_at` より前であってはならない。 |
| `summary` | 文字列 | 任意 | 一覧やフィード向けの 1 段落の要約。 |
| `track.url` | 文字列(URL または相対パス) | 任意 | 記録した軌跡の GPX ファイル。参照のみで、埋め込まない。 |
| `track.format` | 文字列 | 任意 | 既定値 `gpx`。他の軌跡形式のために予約。 |
| `stats.distance_m` | 数値 ≥ 0 | 任意 | 総距離(メートル)。 |
| `stats.ascent_m` | 数値 ≥ 0 | 任意 | 累積標高(登り、メートル)。 |
| `stats.descent_m` | 数値 ≥ 0 | 任意 | 累積標高(下り、メートル)。 |
| `tags` | 文字列のシーケンス | 任意 | 自由なタグ(山域、山名など)。 |
| `members` | 文字列のシーケンス | 任意 | 参加者。表記は著者の自由。 |
| `license` | 文字列 | 任意 | 記録のライセンス。SPDX 識別子(`CC-BY-4.0`)を推奨。 |

未知のキーは保持され(`extra` として出力)、警告 `unknown-field` が報告されます。

文書全体にかかる情報は Front Matter に、本文中の特定の場所や時点に結びつく情報はディレクティブに書きます。同じ事実を両方に書くことは想定しません。

## 3. 本文

本文は CommonMark です。レンダリングライブラリが対応する GitHub 風拡張(テーブル、タスクリスト、脚注、取り消し線)は使用できますが、fmfm としての意味は持ちません。

リンク参照定義は、使用する Markdown セグメント(ディレクティブ間の本文、またはディレクティブ本体)と同じセグメント内に置いてください。v0.1 では、ツールがセグメントをまたいで解決することは任意です。

## 4. ディレクティブ

### 4.1 構文

```text
:::NAME{ATTRIBUTES}
BODY
:::
```

* 開始フェンスは **0 桁目** の `:::` で、直後に `NAME`(`[a-z][a-z0-9-]*`)、その後に任意の空白と省略可能な属性ブロック `{…}` が続きます。行にそれ以外を書くことはできません。
* `ATTRIBUTES` は空白区切りの `key="value"`、`key='value'`、`key=value` の並びです(裸の値は空白・`}`・引用符で終わり、引用符を含められません)。キーは `[a-z][a-z0-9_-]*` に一致します。引用符内のエスケープは `\"`、`\'`、`\\` のみです。`#foo` は `id=foo` の、`.foo` は `class` 属性への `foo` 追加の省略形です。同じキーを 2 回書くと構文エラー(`duplicate-attribute`)です。
* `BODY` は CommonMark で、次にちょうど `:::`(末尾の空白は可)となる行で終わります。終了フェンスは **必須** です(なければ `unclosed-directive`。ツールはファイル末尾までを本体として回復します)。
* v0.1 ではディレクティブは **ネストしません**。本体内の開始フェンスは報告され(`nested-directive`)、テキストとして扱われます。
* トップレベルのコードフェンス内の `:::` 行はフェンスではありません。
* ディレクティブは文書のトップレベルでのみ認識されます。インデントされた `:::` や、引用・リスト項目内の `:::` は普通のテキストです。

属性値は構文レベルでは文字列です。解釈は以下の各ディレクティブ種別で定めます。

### 4.2 共通属性

| 属性 | 型 | 意味 |
| --- | --- | --- |
| `id` | 文字列 | 安定した識別子。HTML の `id` になる。 |
| `class` | 文字列 | 追加の CSS クラス(空白区切り)。 |
| `latitude`, `longitude` | 十進度(WGS 84)。`latitude` は [−90, 90]、`longitude` は [−180, 180] | 位置。両方書くか両方省くかのどちらか(`missing-coordinate`)。 |
| `elevation_m` | 数値 | 標高(メートル)。 |
| `observed_at` | 日時 | 観測した時刻。 |

未知の属性は保持され(JSON の `extra`、HTML の `data-*`)、警告 `unknown-attribute` が報告されます。

### 4.3 `waypoint`

ルート上の名前のある地点。

| 属性 | 必須 | 備考 |
| --- | --- | --- |
| `name` | **必須** | 表示名(小屋、峠、山頂、登山口など)。 |
| `latitude` / `longitude` | 任意 | 共通属性参照。 |
| `elevation_m` | 任意 | |
| `arrived_at` | 任意 | 日時 |
| `departed_at` | 任意 | 日時。`arrived_at` より前であってはならない。 |

本体はその地点についての自由な文章です。

### 4.4 `hazard`

ある場所で登山者を危険にさらす、または通行を妨げるもの。

| 属性 | 必須 | 備考 |
| --- | --- | --- |
| `severity` | **必須** | `info`、`caution`、`warning`、`danger` のいずれか(下記)。 |
| `latitude` / `longitude` | 任意 | |
| `observed_at` | 任意 | |

深刻度:

* `info` — 知っておく価値がある。通常の条件では危険はない(道標の欠落、水場の枯渇)。
* `caution` — 注意が必要。通常の登山技術で対処できる(滑りやすい木の根、短い露出区間)。
* `warning` — 実際の危険がある。迂回や追加の注意・装備を検討する(露出した斜面上の倒木、渡渉が必要な流失した橋)。
* `danger` — 生命に関わる。固有の準備なしに進んではならない(活動中の落石、雪崩地形、垂直区間の固定ロープ欠落)。

### 4.5 `trail-condition`

山行時点での登山道の区間の状態。

| 属性 | 必須 | 備考 |
| --- | --- | --- |
| `status` | **必須** | `good`、`caution`、`impassable` のいずれか。 |
| `section` | 任意 | 区間の自由な名前(`白岩小屋〜雲取山山頂`)。 |
| `latitude` / `longitude` | 任意 | 代表点。 |
| `observed_at` | 任意 | |

* `good` — 想定どおり通行可能。
* `caution` — 追加の注意で通行可能(残雪、泥濘、藪、軽微な浸食)。
* `impassable` — その時点では通過できなかった(崩落、深い雪、増水)。行政による通行止めは v0.1 では本文で記述します。

### 4.6 未知のディレクティブ

本書で定義されていない名前のディレクティブは保持されます。名前、属性、本体は AST・JSON・HTML に残り、警告 `unknown-directive` が報告されます。これにより著者は実験でき、新しい文書は古いツールでも穏やかに劣化します。

## 5. データ型

| 型 | 字句形式 |
| --- | --- |
| 文字列 | 任意のテキスト |
| 数値 | 省略可能な `-`、数字列、省略可能な `.` と数字列(`21300`、`1780.5`)。指数表記と桁区切りは不可 |
| 日時 | RFC 3339 のサブセット: `YYYY-MM-DDTHH:MM:SS[.小数](Z\|±HH:MM)`。タイムゾーンオフセットは **必須**。`T` は小文字でもよく、`T` の代わりの空白も許容。日付のみの値は不可。 |
| 十進度 | 属性ごとに定めた範囲内の数値 |

## 6. バージョニング

`format_version` は `MAJOR.MINOR` です。同じメジャーバージョン内では、省略可能なフィールド・属性・ディレクティブ種別が追加されることはあっても既存の意味は変わらず、未知の項目は前述のとおり保持されます。メジャーバージョン N に対応するツールはすべての N.x 文書を受け入れなければならず、未知のマイナーバージョンには失敗ではなく警告を出すべきです。本書は `0.1` です。1.0 より前のマイナーバージョンでは非互換な変更がありえ、CHANGELOG に記録します。

## 7. 診断

準拠するバリデータは問題を `FILE:LINE:COLUMN: LEVEL[CODE]: MESSAGE` の形式で報告します。行と列は 1 始まりです。レベルは `error`(文書が仕様に準拠していない)と `warning`(準拠しているが意図しない何かがありそう)です。

| コード | レベル | 段階 | 意味 |
| --- | --- | --- | --- |
| `unclosed-front-matter` | error | 構文 | `---` で開いた Front Matter が閉じていない。 |
| `invalid-yaml` | error | 構文 | Front Matter が妥当な YAML でない、または許容外の機能を使っている。 |
| `duplicate-key` | error | 構文 | 同じマッピング内に Front Matter のキーが 2 回現れる。 |
| `invalid-directive-header` | error | 構文 | 開始フェンスの名前の後に余分なテキストがある、または属性ブロックが不正。 |
| `invalid-attribute` | error | 構文 | 属性が `key=value` でない、キーが不正、または引用符が閉じていない。 |
| `duplicate-attribute` | error | 構文 | 同じ属性キーが 2 回現れる。 |
| `unclosed-directive` | error | 構文 | ファイル末尾までに終了の `:::` がない。 |
| `nested-directive` | error | 構文 | ディレクティブ本体内に開始フェンスがある。 |
| `missing-title` | error | 意味 | `title` がない、または空。 |
| `missing-format` | warning | 意味 | `format` / `format_version` がない。 |
| `invalid-format` | error | 意味 | `format` が `fmfm` でない、または `format_version` の形式が不正か、メジャーバージョンが未対応。 |
| `newer-format-version` | warning | 意味 | `format_version` のマイナーバージョンがツールの知るものより新しい。未知の項目は保持される。 |
| `unknown-field` | warning | 意味 | 本仕様で定義されていない Front Matter のキー(保持される)。 |
| `invalid-value` | error | 意味 | フィールドや属性がその型の字句形式でない(不正な数値、不正な日時)。 |
| `invalid-severity` | error | 意味 | `severity` が 4 つのレベルのいずれでもない。 |
| `invalid-status` | error | 意味 | `status` が 3 つの値のいずれでもない。 |
| `out-of-range` | error | 意味 | 緯度・経度が範囲外、または距離・登り・下りが負。 |
| `missing-attribute` | error | 意味 | 必須属性がない。 |
| `missing-coordinate` | error | 意味 | `latitude` / `longitude` の片方だけがある。 |
| `unknown-attribute` | warning | 意味 | このディレクティブで定義されていない属性(保持される)。 |
| `unknown-directive` | warning | 意味 | 本仕様で定義されていないディレクティブ名(保持される)。 |
| `time-order` | error | 意味 | `ended_at` が `started_at` より前、または `departed_at` が `arrived_at` より前。 |

## 8. 出力

### 8.1 JSON

`export --format json` の形は公開の契約です。

```json
{
  "format": "fmfm",
  "format_version": "0.1",
  "metadata": {
    "type": "hike",
    "title": "雲取山を三峰から縦走",
    "started_at": "2026-07-10T06:20:00+09:00",
    "ended_at": "2026-07-10T17:40:00+09:00",
    "track": { "url": "./track.gpx", "format": "gpx" },
    "stats": { "distance_m": 21300, "ascent_m": 1780 },
    "tags": ["奥多摩", "雲取山"]
  },
  "blocks": [
    { "type": "markdown", "source": "# 雲取山縦走\n\n06:20 に……\n" },
    {
      "type": "hazard",
      "severity": "warning",
      "location": { "latitude": 35.87, "longitude": 138.94 },
      "body": [ { "type": "markdown", "source": "白岩小屋の少し下で……\n" } ]
    }
  ]
}
```

文書にない省略可能フィールドは出力されません。未知の Front Matter キーは `metadata.extra` に、未知の属性はブロックの `extra` に現れます。未知のディレクティブは `{ "type": "directive", "name": "...", "attributes": {...}, "body": [...] }` です。

### 8.2 HTML

HTML 出力はセマンティックで、CSS や JavaScript なしでも読めます。ディレクティブはクラス `fmfm-NAME` の `<section>` 要素になり、機械可読な属性は `data-*` になります。

```html
<section class="fmfm-hazard" data-severity="warning" data-latitude="35.87" data-longitude="138.94">
  <p>白岩小屋の少し下で倒木が登山道を塞いでいる。右側から迂回可能。</p>
</section>
```

文書全体は `<article class="fmfm-document" data-format="fmfm" data-format-version="0.1">` で包まれ、タイトルとメタデータを持つ `<header>` を省略可能で含みます。クラス名と `data-*` 名は契約の一部ですが、既定のスタイルシートは契約ではありません。

## 9. 準拠

バリデータが `error` の診断を 1 つも報告しないとき、文書は fmfm 0.1 に準拠します。すべての準拠文書を受け入れ、未知のディレクティブと属性を保持し、§8.1 の JSON 形を出力するとき、プロセッサは準拠します。
