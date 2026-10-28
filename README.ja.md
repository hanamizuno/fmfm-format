# fmfm — 登山記録のためのオープンな Markdown フォーマット

> English: [README.md](README.md)(英語版が正本です)

**fmfm** は、自分のサイトに置く登山(および類似のアウトドア活動)記録のためのファイル形式とツール群です。記録はどのレンダラーでも読める普通の Markdown ファイルで、そこに省略可能な小さな構造を 2 層だけ重ねます。山行全体のメタデータを持つ YAML Front Matter と、他の登山者にとって意味のある地点 — 通過点、危険箇所、登山道状況 — を示す `:::` ディレクティブです。

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

記録の正本は著者の手元に残ります。ツールはそれを検証し、検索インデックスや地図サービス向けの JSON に変換し、セマンティックな HTML に描画します。中央のサービスもロックインもありません。GPX の軌跡は埋め込まずに参照し、ツールが理解できないものは保持されます。

状態: **プレリリース(v0.1 を実装中)**。フォーマットはドラフトで、1.0 より前に非互換な変更がありえます。

## なぜ作るのか

日本の登山記録はいくつかの中央集権的なアプリに集まりがちです。本プロジェクトは逆の立場を取ります。記録は一度だけ Markdown で、自分のブログや git リポジトリに書き、それを任意の数のサービスが読めるようにします。設計目標は優先順に次のとおりです。

1. ツールなしで普通の Markdown として読めること
2. 構造化する価値のある部分だけを、できるだけ小さな記法で構造化すること
3. 既存のオープンな形式に仕事を任せること: CommonMark、YAML、GPX(将来的に GeoJSON、Atom/GeoRSS、OSM と Wikidata の ID)
4. すべての利用側が HTML ではなく 1 つの型付きモデルから出発すること

## 仕様

* [docs/spec/format.md](docs/spec/format.md) — 規範的なドラフト(英語。Front Matter のフィールド、ディレクティブ文法、`waypoint` / `hazard` / `trail-condition`、データ型、診断、JSON と HTML の出力契約)
* [docs/spec/format.ja.md](docs/spec/format.ja.md) — 日本語訳
* 設計理由: [docs/knowledge/adr/](docs/knowledge/adr/index.md)、未決事項: [docs/knowledge/architecture/open-questions.md](docs/knowledge/architecture/open-questions.md)(いずれも英語)

## ツール群

リファレンス実装は [MoonBit](https://www.moonbitlang.com/) で書かれています(モジュール `hanamizuno/fmfm`)。まずライブラリ、次に CLI であり、Markdown を直接 HTML に変換することはしません。

```text
source → syntax(Front Matter + ディレクティブ)→ semantic(型付き Document + 診断)
       → 出力: JSON · HTML ·(GeoJSON、フィードなどは今後)
```

パッケージ: `diagnostic`、`syntax`、`frontmatter`、`ast`、`semantic`、`json`、`html`、およびルートのファサード。詳細は [docs/knowledge/architecture/pipeline-and-packages.md](docs/knowledge/architecture/pipeline-and-packages.md)。

### 予定している CLI

```bash
fmfm validate hike.md            # 診断を file:line:col: level[code]: message で出力。エラーがあれば終了コード 1
fmfm render hike.md -o hike.html # 既定スタイルシート付きのセマンティック HTML
fmfm export hike.md --format json
fmfm dump hike.md                # 位置情報と診断を含む完全な AST(デバッグ用)
```

### 現在の状態

| 領域 | 状態 |
| --- | --- |
| ディレクティブスキャナ、属性文法、Front Matter の切り出し | 完了。スナップショットテスト済み |
| 型付き AST、RFC 3339 日時、数値の字句解析 | 完了 |
| 意味検証(仕様の全診断コード) | 完了 |
| JSON export / dump | 完了 |
| HTML レンダラ(セマンティックな section、`data-*`、エスケープ) | 完了。任意の Markdown→HTML 関数を受け取る |
| `moonbit-community/cmark` による CommonMark 描画 | アダプタ未着手(依存の取得待ち) |
| `moonbit-community/yaml` による YAML Front Matter | リーダ未着手(依存の取得待ち) |
| CLI、既定 CSS、`examples/` のゴールデンテスト | 未着手 |
| GPX 検証、GeoJSON、フィード | v0.1 以降 |

## 開発

[MoonBit ツールチェーン](https://www.moonbitlang.com/download) と [just](https://github.com/casey/just) をインストールして、次を実行します。

```bash
moon update     # レジストリ索引(初回のみ)
just            # check + test(js ターゲット)
just ci-all     # フォーマット、生成インターフェース、js + native のテスト。CI と同じ
```

その他のレシピ: `just fmt`、`just test-update`(スナップショット更新)、`just info`(`pkg.generated.mbti` の再生成)、`just target=native test`。人間と AI エージェント向けの貢献ガイドラインは [AGENTS.md](AGENTS.md)(英語)にあります。

Docker と Docker Sandboxes(`sbx`)の設定はプロジェクトテンプレートから引き継いでいます。[`.sandbox/README.md`](.sandbox/README.md) と [runbook](docs/knowledge/runbooks/agent-sandbox-sbx.md) を参照してください。

## 貢献

Issue と Pull Request を歓迎します。日本語でも英語でも構いません。いま議論の中心にあるのはフォーマットそのものです。登山記録を書いていて、仕様が自分の書き方に合わないと感じたら、Issue で教えてください。

## ライセンス

MIT — [LICENSE](LICENSE) を参照してください。仕様の文章も同じライセンスです。この形式で書いた記録は、当然ながら書いた人のものです。
