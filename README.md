# digger-example

[![Digger Workflow](https://github.com/winebarrel/digger-example/actions/workflows/digger_workflow.yml/badge.svg)](https://github.com/winebarrel/digger-example/actions/workflows/digger_workflow.yml)

[digger](https://github.com/diggerhq/digger) (2025-11-07 に OpenTaco へリブランド) を
backendless モードで動かす例。GitHub Actions + OpenTofu + AWS の OIDC 認証。

backendless はオーケストレータのサーバを立てずに GitHub Actions だけで完結する
モード。plan も apply も CI の中で走るので、クラウドの認証情報は CI から出ない。

## 構成

```
digger.yml                          digger のプロジェクト定義
.github/workflows/digger_workflow.yml
.tool-versions                      ローカル開発用の OpenTofu バージョン
tf/
  tofu.tf                           backend, provider, required_version
  oidc.tf                           GitHub OIDC プロバイダ
  iam.tf                            digger 用の IAM ロールとポリシー
  s3.tf                             state と tfplan を置くバケット
  greeting.tf                       サンプルリソース
```

`tf/` は digger 自身が使う AWS リソースを含んでいる。digger に自分の足場を
管理させる形なので、初回だけローカルから apply して立ち上げる必要がある。

## AWS 側

| リソース | 用途 |
| --- | --- |
| OIDC プロバイダ | GitHub Actions からの AssumeRoleWithWebIdentity |
| `digger-gha` ロール | このリポジトリのワークフローだけが引き受けられる |
| `winebarrel-digger-example` バケット | state と tfplan の両方を置く |
| `DiggerDynamoDBLockTable` | digger の PR ロック。初回実行時に digger が作る |

バケットは1つにまとめている。state は `tf/terraform.tfstate`、tfplan は digger が
`<owner>-<repo>-<PR番号>-<プロジェクト名>.tfplan` という名前でルート直下に書く。

ロールは plan に必要な権限しか持たない。書き込みは state、そのロックファイル、
tfplan、PR ロックの DynamoDB だけで、それ以外は読み取りに絞っている。
apply は人間がローカルから実行する。

## 初回の bootstrap

state を置くバケットをこの構成自身が作るので、鶏卵になる。

1. `tf/tofu.tf` の `backend "s3"` ブロックをコメントアウトする
2. `tf/` で `tofu init` して `tofu apply`
3. `backend` ブロックを戻して `tofu init -migrate-state`

`tofu init -backend=false` では apply できない。backend の初期化を求められる。

あわせてリポジトリ変数 `AWS_ACCOUNT_ID` を設定する。

```
gh variable set AWS_ACCOUNT_ID --body <アカウントID>
```

## 使い方

1. `tf/` を変更して PR を開くと plan が PR コメントに投稿される
2. `digger plan` とコメントすれば再実行される

`digger apply` はロールが読み取り専用なので失敗する。apply はローカルから
`tofu apply` で実行する。

## 参考

- [Digger を試してみた](https://qiita.com/minamijoyo/items/b61806b570d9d1257f0b)
- [OpenTaco (Digger) Backendless モードの落とし穴](https://zenn.dev/odetarou/articles/opentaco-digger-backendless-terraform-ci)
- [OpenTaco のドキュメント](https://docs.opentaco.dev/introduction/introduction)
