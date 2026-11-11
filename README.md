# SlingArc

> **開発中です。** 今はタイトル画面だけで、まだ遊べません。

画面を引っ張って探査機を撃ち出し、惑星の重力で軌道を曲げてゴールに入れる、ブラウザで遊ぶ 2D ゲームです。5 ホールで 1 コース、合計の打数が少ないほど良い。

- 遊ぶ: https://takosasi-dev.github.io/sling-arc/ (デスクトップの Chrome・Edge・Firefox)

## 動作環境

- Godot 4.7.2-stable(GDScript、レンダラー Compatibility)
- Web 書き出しはスレッド無し・拡張無し

## 開発

```
# テスト(全件成功で終了コード 0)
godot --headless --import
godot --headless --script res://tests/run_tests.gd

# Web 書き出し(書き出しテンプレート 4.7.2 が要る)
godot --headless --export-release "Web" build/web/index.html
```

`main` に push すると、GitHub Actions(`.github/workflows/pages.yml`)がテスト・Web 書き出し・GitHub Pages への配置を行います。テストが落ちたら配置しません。書き出し結果(`build/`)はコミットしません。

## ライセンス

コードは [MIT](LICENSE)。同梱フォント(Noto Sans JP)は SIL Open Font License 1.1 です。詳しくは [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。
