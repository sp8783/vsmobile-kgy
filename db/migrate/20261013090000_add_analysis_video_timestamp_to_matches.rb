class AddAnalysisVideoTimestampToMatches < ActiveRecord::Migration[8.1]
  def change
    # 動画解析（exvs2ib-replay-parser）が出したタイムスタンプ。試合の開始時刻から計算したタイムスタンプと比べるために別に残す
    add_column :matches, :analysis_video_timestamp, :integer
  end
end
