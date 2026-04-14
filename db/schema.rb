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

ActiveRecord::Schema[8.0].define(version: 2026_04_14_122353) do
  create_table "band_memberships", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "band_id", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_band_memberships_on_band_id"
    t.index ["user_id"], name: "index_band_memberships_on_user_id"
  end

  create_table "bands", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_bands_on_slug", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.integer "band_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_events_on_band_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.integer "band_id", null: false
    t.integer "invited_by_id", null: false
    t.string "token"
    t.string "email_address"
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_invitations_on_band_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "musics", force: :cascade do |t|
    t.integer "band_id", null: false
    t.string "title"
    t.string "artist"
    t.text "lyrics"
    t.text "chords"
    t.string "spotify_url"
    t.string "youtube_url"
    t.string "spotify_track_id"
    t.decimal "bpm", precision: 5, scale: 1
    t.string "key_name"
    t.string "key_mode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id", "title"], name: "index_musics_on_band_id_and_title"
    t.index ["band_id"], name: "index_musics_on_band_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "setlist_items", force: :cascade do |t|
    t.integer "setlist_id", null: false
    t.integer "position", default: 0, null: false
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_setlist_items_on_item"
    t.index ["setlist_id", "position"], name: "index_setlist_items_on_setlist_id_and_position"
    t.index ["setlist_id"], name: "index_setlist_items_on_setlist_id"
  end

  create_table "setlists", force: :cascade do |t|
    t.integer "band_id", null: false
    t.string "title"
    t.date "performance_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["band_id"], name: "index_setlists_on_band_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "band_memberships", "bands"
  add_foreign_key "band_memberships", "users"
  add_foreign_key "events", "bands"
  add_foreign_key "invitations", "bands"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "musics", "bands"
  add_foreign_key "sessions", "users"
  add_foreign_key "setlist_items", "setlists"
  add_foreign_key "setlists", "bands"
end
