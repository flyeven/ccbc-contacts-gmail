# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20160808001104) do

  create_table "ccb_configs", force: :cascade do |t|
    t.string   "subdomain"
    t.string   "encrypted_api_user"
    t.string   "encrypted_api_password"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.date     "since"
    t.string   "encrypted_api_user_iv"
    t.string   "encrypted_api_password_iv"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority"

  create_table "individuals", force: :cascade do |t|
    t.integer "ccb_config_id"
    t.integer "individual_id"
    t.text    "object_json"
    t.integer "family_id"
  end

  add_index "individuals", ["ccb_config_id", "individual_id"], name: "index_individuals_on_ccb_config_id_and_individual_id"
  add_index "individuals", ["family_id"], name: "index_individuals_on_family_id"

  create_table "users", force: :cascade do |t|
    t.string   "name"
    t.string   "email"
    t.string   "md5"
    t.text     "authorization"
    t.date     "since"
    t.boolean  "recurring"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "ccb_id"
    t.text     "options"
    t.integer  "ccb_config_id"
  end

  add_index "users", ["email"], name: "index_users_on_email"
  add_index "users", ["md5"], name: "index_users_on_md5"

end
