class AddSkippedToRotationMatches < ActiveRecord::Migration[8.1]
  def up
    add_column :rotation_matches, :skipped, :boolean, default: false, null: false

    # これまでは「現在の試合以外で未記録のまま開始済み（現在より前を含む）」をスキップ扱いしていた。
    # 対戦済みで結果が未入力の試合と区別するため、既存データの該当試合はスキップとして明示する。
    execute <<~SQL
      UPDATE rotation_matches rm
      SET skipped = TRUE
      FROM rotations r
      WHERE rm.rotation_id = r.id
      AND rm.match_id IS NULL
      AND rm.match_index <> r.current_match_index
      AND (rm.match_index < r.current_match_index OR rm.started_at IS NOT NULL)
    SQL
  end

  def down
    remove_column :rotation_matches, :skipped
  end
end
