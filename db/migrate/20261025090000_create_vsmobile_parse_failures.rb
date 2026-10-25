class CreateVsmobileParseFailures < ActiveRecord::Migration[8.1]
  # ブックマークレットから届いた試合ページの HTML を解析・対応づけできなかったときの記録。
  # ブックマークレットは参加者のブラウザで動くので管理者は再現できない。何が届いたかを残して、手元で原因を追う
  def change
    create_table :vsmobile_parse_failures do |t|
      t.references :user, null: true, foreign_key: { on_delete: :nullify }
      t.references :event, null: true, foreign_key: { on_delete: :nullify }
      t.bigint :match_ts
      t.string :error_message, null: false
      t.jsonb :request_params, null: false, default: {}
      t.text :html, null: false
      t.timestamps
    end
  end
end
