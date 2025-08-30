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

ActiveRecord::Schema[8.0].define(version: 2025_08_30_041132) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_insights", force: :cascade do |t|
    t.bigint "audit_session_id", null: false
    t.text "summary"
    t.json "key_findings"
    t.json "risk_indicators"
    t.float "overall_score"
    t.integer "confidence_level", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_session_id"], name: "index_audit_insights_on_audit_session_id"
    t.index ["confidence_level"], name: "index_audit_insights_on_confidence_level"
    t.index ["overall_score"], name: "index_audit_insights_on_overall_score"
  end

  create_table "audit_sessions", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "audit_template_id", null: false
    t.integer "status", default: 0
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "session_token", null: false
    t.integer "current_question_index", default: 0
    t.string "preferred_voice", default: "en-US-Neural2-C"
    t.boolean "speech_enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_template_id"], name: "index_audit_sessions_on_audit_template_id"
    t.index ["session_token"], name: "index_audit_sessions_on_session_token", unique: true
    t.index ["status"], name: "index_audit_sessions_on_status"
    t.index ["user_id"], name: "index_audit_sessions_on_user_id"
  end

  create_table "audit_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true
    t.integer "estimated_duration_minutes"
    t.text "intro_message"
    t.text "outro_message"
    t.string "default_voice", default: "en-US-Neural2-C"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_audit_templates_on_active"
    t.index ["name"], name: "index_audit_templates_on_name", unique: true
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "audit_template_id", null: false
    t.text "text", null: false
    t.text "speech_text"
    t.integer "sequence", null: false
    t.integer "question_type", default: 0
    t.integer "max_response_seconds", default: 120
    t.json "expected_keywords"
    t.json "followup_prompts"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_template_id", "sequence"], name: "index_questions_on_audit_template_id_and_sequence", unique: true
    t.index ["audit_template_id"], name: "index_questions_on_audit_template_id"
    t.index ["question_type"], name: "index_questions_on_question_type"
  end

  create_table "responses", force: :cascade do |t|
    t.bigint "audit_session_id", null: false
    t.bigint "question_id", null: false
    t.text "transcribed_text"
    t.integer "original_audio_duration_seconds"
    t.datetime "responded_at"
    t.integer "transcription_status", default: 0
    t.float "transcription_confidence"
    t.json "speech_analysis"
    t.boolean "requires_clarification", default: false
    t.text "clarification_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audit_session_id", "question_id"], name: "index_responses_on_audit_session_id_and_question_id", unique: true
    t.index ["audit_session_id"], name: "index_responses_on_audit_session_id"
    t.index ["question_id"], name: "index_responses_on_question_id"
    t.index ["responded_at"], name: "index_responses_on_responded_at"
    t.index ["transcription_status"], name: "index_responses_on_transcription_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.datetime "last_audit_at"
    t.string "preferred_voice", default: "en-US-Neural2-C"
    t.string "preferred_language", default: "en-US"
    t.boolean "speech_enabled", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "audit_insights", "audit_sessions"
  add_foreign_key "audit_sessions", "audit_templates"
  add_foreign_key "audit_sessions", "users"
  add_foreign_key "questions", "audit_templates"
  add_foreign_key "responses", "audit_sessions"
  add_foreign_key "responses", "questions"
end
