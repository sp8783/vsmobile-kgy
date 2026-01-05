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

ActiveRecord::Schema[8.1].define(version: 2025_12_30_220603) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "held_on", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["held_on"], name: "index_events_on_held_on"
  end

  create_table "match_players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "match_id", null: false
    t.bigint "mobile_suit_id", null: false
    t.integer "position", null: false
    t.integer "team_number", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["match_id", "position"], name: "index_match_players_on_match_id_and_position", unique: true
    t.index ["match_id", "team_number"], name: "index_match_players_on_match_id_and_team_number"
    t.index ["match_id"], name: "index_match_players_on_match_id"
    t.index ["mobile_suit_id"], name: "index_match_players_on_mobile_suit_id"
    t.index ["team_number"], name: "index_match_players_on_team_number"
    t.index ["user_id", "mobile_suit_id"], name: "index_match_players_on_user_id_and_mobile_suit_id"
    t.index ["user_id"], name: "index_match_players_on_user_id"
  end

  create_table "matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "played_at", null: false
    t.bigint "rotation_match_id"
    t.datetime "updated_at", null: false
    t.integer "winning_team", null: false
    t.index ["event_id", "played_at"], name: "index_matches_on_event_id_and_played_at"
    t.index ["event_id"], name: "index_matches_on_event_id"
    t.index ["played_at"], name: "index_matches_on_played_at"
    t.index ["rotation_match_id"], name: "index_matches_on_rotation_match_id"
  end

  create_table "mobile_suits", force: :cascade do |t|
    t.integer "cost", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position"
    t.string "series", null: false
    t.datetime "updated_at", null: false
    t.index ["cost"], name: "index_mobile_suits_on_cost"
    t.index ["name"], name: "index_mobile_suits_on_name"
  end

  create_table "rotation_matches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "match_id"
    t.integer "match_index", null: false
    t.bigint "rotation_id", null: false
    t.bigint "team1_player1_id", null: false
    t.bigint "team1_player2_id", null: false
    t.bigint "team2_player1_id", null: false
    t.bigint "team2_player2_id", null: false
    t.datetime "updated_at", null: false
    t.index ["match_id"], name: "index_rotation_matches_on_match_id"
    t.index ["rotation_id", "match_index"], name: "index_rotation_matches_on_rotation_id_and_match_index", unique: true
    t.index ["rotation_id"], name: "index_rotation_matches_on_rotation_id"
  end

  create_table "rotations", force: :cascade do |t|
    t.bigint "base_rotation_id"
    t.datetime "created_at", null: false
    t.integer "current_match_index", default: 0, null: false
    t.bigint "event_id", null: false
    t.boolean "is_active", default: false, null: false
    t.string "name", null: false
    t.integer "round_number", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["base_rotation_id"], name: "index_rotations_on_base_rotation_id"
    t.index ["event_id", "is_active"], name: "index_rotations_on_event_id_and_is_active"
    t.index ["event_id"], name: "index_rotations_on_event_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "is_admin", default: false, null: false
    t.string "nickname", null: false
    t.boolean "notification_enabled", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "match_players", "matches"
  add_foreign_key "match_players", "mobile_suits"
  add_foreign_key "match_players", "users"
  add_foreign_key "matches", "events"
  add_foreign_key "matches", "rotation_matches"
  add_foreign_key "rotation_matches", "matches"
  add_foreign_key "rotation_matches", "rotations"
  add_foreign_key "rotation_matches", "users", column: "team1_player1_id"
  add_foreign_key "rotation_matches", "users", column: "team1_player2_id"
  add_foreign_key "rotation_matches", "users", column: "team2_player1_id"
  add_foreign_key "rotation_matches", "users", column: "team2_player2_id"
  add_foreign_key "rotations", "events"
  add_foreign_key "rotations", "rotations", column: "base_rotation_id"
end
