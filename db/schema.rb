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

ActiveRecord::Schema.define(version: 20141112070817) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "blockqueues", force: true do |t|
    t.integer  "task"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "troll_id"
  end

  add_index "blockqueues", ["troll_id"], name: "index_blockqueues_on_troll_id", using: :btree
  add_index "blockqueues", ["user_id"], name: "index_blockqueues_on_user_id", using: :btree

  create_table "delayed_jobs", force: true do |t|
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

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "lists", force: true do |t|
    t.string   "name"
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "owner_id"
    t.boolean  "auto_add_new_blocks"
    t.text     "block_list"
  end

  add_index "lists", ["owner_id"], name: "index_lists_on_owner_id", using: :btree

  create_table "lists_users", id: false, force: true do |t|
    t.integer "list_id", null: false
    t.integer "user_id", null: false
  end

  add_index "lists_users", ["list_id"], name: "index_lists_users_on_list_id", using: :btree
  add_index "lists_users", ["user_id"], name: "index_lists_users_on_user_id", using: :btree

  create_table "trolls", force: true do |t|
    t.string   "name",                   default: "Unknown..."
    t.string   "screen_name",            default: "unknown"
    t.string   "image_url",              default: "https://pbs.twimg.com/profile_images/523989065352232961/ZF2MvbfP_bigger.png"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "uid",          limit: 8
    t.boolean  "checked",                default: false
    t.datetime "last_checked"
    t.boolean  "suspended",              default: false
    t.boolean  "notfound",               default: false
  end

  create_table "users", force: true do |t|
    t.string   "access_token"
    t.string   "access_secret"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "image_url"
    t.string   "screen_name"
    t.string   "name"
    t.boolean  "declined",                default: false
    t.text     "friend_list"
    t.integer  "uid",           limit: 8
    t.text     "block_list"
    t.boolean  "oversized",               default: false
    t.boolean  "suspended",               default: false
    t.boolean  "notfound",                default: false
    t.text     "own_blocks"
  end

end
