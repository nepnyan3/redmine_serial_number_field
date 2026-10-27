# Redmine Serial Number Field

[English »](README.en.md)

Redmine に自動で連番を付加するカスタムフィールドを提供するプラグインです。

## Features

* チケットに対するカスタムフィールドの書式として「自動採番」が利用可能になります。
  * カスタムフィールドの新規作成後は、正規表現を編集することは、できません。
  * チケットが登録できる、全てのユーザーは、自動採番の権限があります。
* 指定した正規表現に基づいて、チケット登録や更新時（一括操作も含む）に自動的に採番します。
  * カスタムフィールド単位での採番となります。同じカスタムフィールドを複数のプロジェクトで使用している場合は、それらのプロジェクトで連続した採番になります。
  * カスタムフィールド項目は、チケットの閲覧時には表示します。しかし、登録および更新時には表示しません。
* チケットのフィルタ条件、検索対象など、カスタムフィールドの基本的なオプションも利用可能です。

### Notes

#### 採番済みチケットのトラッカーやプロジェクトを変更した場合

* 変更後のトラッカーが同じカスタムフィールドを持っていない場合、採番された連番は削除されます。
* 変更後のトラッカーが同じカスタムフィールドを持っている場合、採番された連番は変化しません。

#### ワークフローのカスタムフィールドに対する権限を設定した場合

* 自動採番のカスタムフィールドを読み取り専用に設定すると動作がおかしくなる場合があります。

## Usage

1. チケットの新しいカスタムフィールドを作成します。
2. 項目「書式」を自動採番に変更します。
3. 項目「正規表現」に年表記書式や連番書式を指定します。
4. フィルタや検索条件として使いたい場合は、適宜チェックを入れます。
5. 自動採番をしたいトラッカーとプロジェクトを指定します。
6. 完了です。
    * 新たにチケットを作成すれば自動で採番されます。
    * 既に作成されたチケットは何かしら更新すれば採番されます。

## Screenshot

*Administration > Custom fields > Issues > 自動採番*

![usage.png](https://github.com/matsukei/redmine_serial_number_field/blob/master/doc/images/usage.png)

*Issues*

![issues.png](https://github.com/matsukei/redmine_serial_number_field/blob/master/doc/images/issues.png)

## Supported versions

* Redmine 7.0.2 / Rails 8.1.4 / Ruby 4.0.9 / PostgreSQL 17.6

Redmine 7 向けのフォークです。上記の組み合わせで検証しています。旧 Redmine、他の Ruby バージョン、MySQL・SQLite は未検証です。原作者と MIT ライセンスを継承しています。

## Redmine 7 版の採番動作

* 採番範囲は従来どおりカスタムフィールド単位です。同じフィールドを使う複数プロジェクトでも連番を共有します。
* 発行済みの番号は通常の更新で維持し、コピーには新しい番号を発行します。フォームや API から送られた採番値は無視します。
* 最後の `{0000}` は最小桁数です。上限を超えると `9999` → `10000` → `10001` と桁が増えます。従来の文字列比較による桁あふれ後の重複を修正しました。
* 接頭辞は正規表現ではなく文字列として扱います。記号、日本語、連番直前の固定数字も維持します。例: `A0{00}` は `A099` → `A0100`。複数の数値トークンがある場合、最後以外は従来の初期値 `01` 等を使います。
* 日付はチケットの作成日時を使います。`YYYY` / `YY` の年度は 4 月 1 日に切り替わり、日付を含む接頭辞ごとに番号を採番します。
* PostgreSQL では、チケット保存トランザクション内でフィールドの行をロックし、同時保存時の重複を防止します。採番に失敗すればチケット保存もロールバックします。
* 既存の最大値を基準にする方式は維持しています。最大番号のチケットを削除・対象外へ移動した後は、その番号が再利用される場合があります。既存データの重複を自動修正する機能はありません。

## Format specifications

|採番対象の日付             |年表記書式 |年度(4/1 - 3/31)       |例: 正規表現             |例: 結果(2015-03-31)   |
|---------------------------|-----------|-----------------------|-------------------------|-----------------------|
|Issue#created_on           |`yyyy`     |No                     |`{yyyy}-{0000}`          |`2015-0001`            |
|^                          |`yy`       |No                     |`{yy}-{0000}`            |`15-0001`              |
|^                          |`YYYY`     |Yes                    |`{YYYY}-{0000}`          |`2014-0001`            |
|^                          |`YY`       |Yes                    |`{YY}-{0000}`            |`14-0001`              |
|^                          |`ISO`      |No                     |`{ISO}-{0000}`           |`20150331-0001`        |

* OK
  * `{000000}` #=> `000001`
  * `ABC-{yy}-{00}` #=> `ABC-15-01`
* NG
  * 末尾が連番書式でない場合
    * e.g. `ABC-{000}-{yy}`
  * 年表記書式、連番書式でない場合
    * e.g. `{abc}-{yy}-{000}`

## Install

1. `your_redmine_path/plugins/redmine_serial_number_field/` に clone もしくはダウンロードしたソースを配置します
2. `$ cd your_redmine_path/`
3. `$ bundle install`
4. Redmineを再起動してください

## 開発・テスト

Redmine 本体の `plugins/redmine_serial_number_field` にこのリポジトリを配置し、本体ディレクトリで実行します。開発・テスト用 PostgreSQL を使い、本番の DB やメール設定は使用しないでください。

```sh
bundle config set without ''
bundle install
RAILS_ENV=test bundle exec rake db:create db:migrate
RAILS_ENV=test bundle exec rake redmine:plugins:test NAME=redmine_serial_number_field
RAILS_ENV=development bundle exec rake db:create db:migrate
RAILS_ENV=development bundle exec rails runner plugins/redmine_serial_number_field/test/reload_smoke.rb
```

既存の作成・更新・コピー・一括更新・プロジェクト／トラッカー変更のテストに、日付／年度、桁あふれ、記号、権限、入力改ざん、ロールバック、4 接続での同時採番テストを追加しています。同時採番テストは非トランザクションのフィクスチャを使うため、他のテストプロセスと同じテスト DB を同時に使用しないでください。CI は同じ Redmine／PostgreSQL の公式イメージを使います。

## License

[The MIT License](https://opensource.org/licenses/MIT)
