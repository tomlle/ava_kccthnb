# AVA_KCCT本部 クランHP ミラー

`AVA_KCCT本部 クランHP` の公開ページ本文と添付画像を保存した静的ミラーです。表示時に元サイトの画像・CSS・スクリプトを読み込まないため、元サイトが終了しても保存済みコンテンツを閲覧できます。

```powershell
npm start
```

ブラウザで `http://localhost:3000` を開いてください。保存元を再取得する場合は `npm run sync`、全ページ・ローカル画像参照の確認は `npm run check` を使用します。

## GitHub Pages

`main` ブランチへpushすると、GitHub Actionsが静的ファイルを検証してGitHub Pagesへ公開します。

公開URL: https://tomlle.github.io/ava_kccthnb/

初回のみ、GitHubのリポジトリ設定で **Settings → Pages → Source → GitHub Actions** を選択してください。

ミラー対象はサイトの全29ページです。このうち11ページは元サイトでメンバーまたは管理者限定となっており、公開バックアップも存在しないため、制限の説明だけを保存しています。

本文の著作権は元サイトの各投稿者に帰属します。元サイトが閲覧可能な場合は、元サイトを優先してください。
