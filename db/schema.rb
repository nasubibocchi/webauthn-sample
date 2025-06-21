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

ActiveRecord::Schema[7.2].define(version: 2025_06_20_053153) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "passkeys", force: :cascade do |t|
    t.bigint "webauthn_user_id", null: false
    t.string "label"
    t.string "external_id"
    t.string "public_key"
    t.integer "sign_count"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["webauthn_user_id"], name: "index_passkeys_on_webauthn_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_passwordless", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.check_constraint "length(encrypted_password::text) >= 60 OR is_passwordless = true", name: "ensure_strong_password_unless_passwordless"
  end

  create_table "webauthn_users", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "webauthn_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_webauthn_users_on_user_id"
  end

  add_foreign_key "passkeys", "webauthn_users"
  add_foreign_key "webauthn_users", "users"
end
