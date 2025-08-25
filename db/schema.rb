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

ActiveRecord::Schema[8.0].define(version: 2025_08_25_061946) do
  create_table "characters", force: :cascade do |t|
    t.string "name"
    t.string "series"
    t.integer "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "matches", force: :cascade do |t|
    t.integer "team1_id", null: false
    t.integer "team2_id", null: false
    t.integer "winner_id", null: false
    t.date "match_date", null: false
    t.integer "order", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["team1_id"], name: "index_matches_on_team1_id"
    t.index ["team2_id"], name: "index_matches_on_team2_id"
    t.index ["winner_id"], name: "index_matches_on_winner_id"
  end

  create_table "players", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "teams", force: :cascade do |t|
    t.string "name", null: false
    t.integer "player1_id", null: false
    t.integer "player2_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player1_id"], name: "index_teams_on_player1_id"
    t.index ["player2_id"], name: "index_teams_on_player2_id"
  end

  create_table "test_users", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "usages", force: :cascade do |t|
    t.integer "match_id", null: false
    t.integer "player_id", null: false
    t.integer "team_id", null: false
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_usages_on_character_id"
    t.index ["match_id"], name: "index_usages_on_match_id"
    t.index ["player_id"], name: "index_usages_on_player_id"
    t.index ["team_id"], name: "index_usages_on_team_id"
  end

  add_foreign_key "matches", "teams", column: "team1_id"
  add_foreign_key "matches", "teams", column: "team2_id"
  add_foreign_key "matches", "teams", column: "winner_id"
  add_foreign_key "teams", "players", column: "player1_id"
  add_foreign_key "teams", "players", column: "player2_id"
  add_foreign_key "usages", "characters"
  add_foreign_key "usages", "matches"
  add_foreign_key "usages", "players"
  add_foreign_key "usages", "teams"
end
