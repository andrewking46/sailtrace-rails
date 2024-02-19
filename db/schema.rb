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

ActiveRecord::Schema[7.1].define(version: 2024_02_19_061116) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "boat_classes", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "is_one_design", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_boat_classes_on_name", unique: true
  end

  create_table "boats", force: :cascade do |t|
    t.string "name"
    t.string "registration_country", null: false
    t.string "sail_number", null: false
    t.string "hull_color", null: false
    t.bigint "boat_class_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["boat_class_id"], name: "index_boats_on_boat_class_id"
    t.index ["user_id"], name: "index_boats_on_user_id"
  end

  create_table "races", force: :cascade do |t|
    t.string "name"
    t.datetime "started_at", null: false
    t.decimal "start_latitude", precision: 10, scale: 6, null: false
    t.decimal "start_longitude", precision: 10, scale: 6, null: false
    t.bigint "boat_class_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["boat_class_id"], name: "index_races_on_boat_class_id"
  end

  create_table "recorded_locations", force: :cascade do |t|
    t.decimal "latitude", precision: 10, scale: 6, null: false
    t.decimal "longitude", precision: 10, scale: 6, null: false
    t.decimal "velocity"
    t.integer "heading"
    t.bigint "recording_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_recorded_locations_on_recording_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.string "name"
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.string "time_zone", null: false
    t.boolean "is_race", default: false, null: false
    t.bigint "boat_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "race_id"
    t.decimal "start_latitude", precision: 10, scale: 6
    t.decimal "start_longitude", precision: 10, scale: 6
    t.index ["boat_id"], name: "index_recordings_on_boat_id"
    t.index ["race_id"], name: "index_recordings_on_race_id"
    t.index ["start_latitude", "start_longitude"], name: "index_recordings_on_start_latitude_and_start_longitude"
    t.index ["user_id"], name: "index_recordings_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_active_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email_address", null: false
    t.string "phone_number"
    t.string "country"
    t.string "time_zone"
    t.boolean "is_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["is_admin"], name: "index_users_on_is_admin"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "boats", "boat_classes"
  add_foreign_key "boats", "users"
  add_foreign_key "races", "boat_classes"
  add_foreign_key "recorded_locations", "recordings"
  add_foreign_key "recordings", "boats"
  add_foreign_key "recordings", "races"
  add_foreign_key "recordings", "users"
  add_foreign_key "sessions", "users"
end
