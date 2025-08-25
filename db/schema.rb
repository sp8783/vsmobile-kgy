# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_08_25_171617) do
  create_table "events", force: :cascade do |t|
    t.string "name"
    t.date "date"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "event_type"
    t.string "location"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "match_players", force: :cascade do |t|
    t.integer "match_id", null: false
    t.integer "player_id", null: false
    t.integer "team_id", null: false
    t.integer "mobile_suit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_match_players_on_match_id"
    t.index ["mobile_suit_id"], name: "index_match_players_on_mobile_suit_id"
    t.index ["player_id"], name: "index_match_players_on_player_id"
    t.index ["team_id"], name: "index_match_players_on_team_id"
  end

  create_table "matches", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "team1_id", null: false
    t.integer "team2_id", null: false
    t.integer "winner_team_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_matches_on_event_id"
    t.index ["team1_id"], name: "index_matches_on_team1_id"
    t.index ["team2_id"], name: "index_matches_on_team2_id"
    t.index ["winner_team_id"], name: "index_matches_on_winner_team_id"
  end

  create_table "mobile_suits", force: :cascade do |t|
    t.string "name"
    t.integer "cost"
    t.string "series"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rotation_template_matches", force: :cascade do |t|
    t.integer "rotation_template_id", null: false
    t.integer "order", null: false
    t.integer "team1_player1_index", null: false
    t.integer "team1_player2_index", null: false
    t.integer "team2_player1_index", null: false
    t.integer "team2_player2_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rotation_template_id"], name: "index_rotation_template_matches_on_rotation_template_id"
  end

  create_table "rotation_templates", force: :cascade do |t|
    t.string "name"
    t.integer "player_count"
    t.integer "match_count"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "teams", force: :cascade do |t|
    t.integer "player1_id", null: false
    t.integer "player2_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player1_id", "player2_id"], name: "index_teams_on_player1_id_and_player2_id", unique: true
    t.index ["player1_id"], name: "index_teams_on_player1_id"
    t.index ["player2_id"], name: "index_teams_on_player2_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "match_players", "matches"
  add_foreign_key "match_players", "mobile_suits"
  add_foreign_key "match_players", "teams"
  add_foreign_key "match_players", "users", column: "player_id"
  add_foreign_key "matches", "events"
  add_foreign_key "matches", "teams", column: "team1_id"
  add_foreign_key "matches", "teams", column: "team2_id"
  add_foreign_key "matches", "teams", column: "winner_team_id"
  add_foreign_key "rotation_template_matches", "rotation_templates"
  add_foreign_key "teams", "users", column: "player1_id"
  add_foreign_key "teams", "users", column: "player2_id"
end
