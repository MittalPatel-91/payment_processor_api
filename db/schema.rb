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

ActiveRecord::Schema[8.1].define(version: 2026_03_26_160818) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at"
    t.datetime "failed_at"
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "locked_at"
    t.string "locked_by"
    t.integer "priority", default: 0, null: false
    t.string "queue"
    t.datetime "run_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "payments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.jsonb "payload", default: {}
    t.uuid "request_uuid", null: false
    t.jsonb "response", default: {}
    t.integer "retry_count", default: 0
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.index ["request_uuid"], name: "index_payments_on_request_uuid", unique: true
    t.index ["status"], name: "index_payments_on_status"
  end
end
