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

ActiveRecord::Schema[8.1].define(version: 2026_11_04_210000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "budget_lines", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "kind", null: false
    t.string "description", null: false
    t.integer "estimated_cents", null: false
    t.integer "actual_cents"
    t.integer "status", default: 0, null: false
    t.bigint "responsible_person_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_budget_lines_on_project_id"
    t.index ["responsible_person_id"], name: "index_budget_lines_on_responsible_person_id"
  end

  create_table "check_ins", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "person_id", null: false
    t.bigint "checked_in_by_id"
    t.date "on", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checked_in_by_id"], name: "index_check_ins_on_checked_in_by_id"
    t.index ["organization_id"], name: "index_check_ins_on_organization_id"
    t.index ["person_id"], name: "index_check_ins_on_person_id"
  end

  create_table "comments", force: :cascade do |t|
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.bigint "author_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable"
  end

  create_table "doc_items", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "author_id", null: false
    t.integer "kind", null: false
    t.string "title", null: false
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_doc_items_on_author_id"
    t.index ["project_id"], name: "index_doc_items_on_project_id"
  end

  create_table "follows", force: :cascade do |t|
    t.string "followable_type", null: false
    t.bigint "followable_id", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["followable_type", "followable_id", "person_id"], name: "index_follows_on_followable_and_person", unique: true
    t.index ["followable_type", "followable_id"], name: "index_follows_on_followable"
    t.index ["person_id"], name: "index_follows_on_person_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "project_id", null: false
    t.bigint "person_id", null: false
    t.bigint "inviter_id", null: false
    t.integer "role", null: false
    t.integer "status", default: 0, null: false
    t.datetime "responded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inviter_id"], name: "index_invitations_on_inviter_id"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["person_id"], name: "index_invitations_on_person_id"
    t.index ["project_id", "person_id"], name: "index_invitations_on_pending_project_and_person", unique: true, where: "(status = 0)"
    t.index ["project_id"], name: "index_invitations_on_project_id"
  end

  create_table "list_columns", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.string "name", null: false
    t.integer "column_type", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id"], name: "index_list_columns_on_list_id"
  end

  create_table "list_rows", force: :cascade do |t|
    t.bigint "list_id", null: false
    t.integer "position", null: false
    t.jsonb "cells", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["list_id"], name: "index_list_rows_on_list_id"
  end

  create_table "lists", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_lists_on_project_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "person_id", null: false
    t.integer "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_memberships_on_person_id"
    t.index ["project_id", "person_id"], name: "index_memberships_on_project_id_and_person_id", unique: true
    t.index ["project_id"], name: "index_memberships_on_project_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.string "mentionable_type", null: false
    t.bigint "mentionable_id", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mentionable_type", "mentionable_id", "person_id"], name: "index_mentions_on_mentionable_and_person", unique: true
    t.index ["mentionable_type", "mentionable_id"], name: "index_mentions_on_mentionable"
    t.index ["person_id"], name: "index_mentions_on_person_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "author_id", null: false
    t.bigint "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_messages_on_author_id"
    t.index ["parent_id"], name: "index_messages_on_parent_id"
    t.index ["project_id"], name: "index_messages_on_project_id"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "notable_type", null: false
    t.bigint "notable_id", null: false
    t.bigint "author_id", null: false
    t.integer "visibility", default: 0, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_notes_on_author_id"
    t.index ["notable_type", "notable_id"], name: "index_notes_on_notable"
    t.index ["organization_id"], name: "index_notes_on_organization_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "recipient_id", null: false
    t.integer "kind", null: false
    t.string "notifiable_type", null: false
    t.bigint "notifiable_id", null: false
    t.bigint "actor_id"
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.boolean "demo", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "overextended_limit", default: 3, null: false
    t.text "pco_app_id"
    t.text "pco_secret"
    t.datetime "pco_last_synced_at"
    t.jsonb "pco_last_sync_result", default: {}, null: false
    t.text "pco_last_sync_error"
    t.string "mark_color", default: "#D69000", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.boolean "admin", default: false, null: false
    t.datetime "last_signed_in_at"
    t.string "external_source"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "email_preferences", default: {}, null: false
    t.string "skills", default: [], null: false, array: true
    t.index ["organization_id", "email"], name: "index_people_on_organization_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["organization_id", "external_source", "external_id"], name: "index_people_on_organization_and_external_identity", unique: true, where: "(external_id IS NOT NULL)"
    t.index ["organization_id"], name: "index_people_on_organization_id"
    t.index ["skills"], name: "index_people_on_skills", using: :gin
  end

  create_table "planner_sessions", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "started_by_id", null: false
    t.text "description", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "steps", default: [], null: false
    t.jsonb "current_card"
    t.jsonb "suggestions", default: [], null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "flow_version", default: 1, null: false
    t.integer "generation_revision", default: 0, null: false
    t.string "generation_state", default: "idle", null: false
    t.jsonb "prepared_card"
    t.jsonb "pending_answer"
    t.jsonb "pending_items", default: [], null: false
    t.datetime "accepted_at"
    t.string "planning_kind", default: "meal_train", null: false
    t.index ["project_id"], name: "index_planner_sessions_on_project_id"
    t.index ["started_by_id"], name: "index_planner_sessions_on_started_by_id"
  end

  create_table "project_debriefs", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.text "what_worked", default: "", null: false
    t.text "change_next_time", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_debriefs_on_project_id", unique: true
  end

  create_table "project_occurrences", force: :cascade do |t|
    t.bigint "project_recurrence_id", null: false
    t.bigint "project_id"
    t.date "on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_occurrences_on_project_id", unique: true
    t.index ["project_recurrence_id", "on"], name: "index_project_occurrences_on_project_recurrence_id_and_on", unique: true
    t.index ["project_recurrence_id"], name: "index_project_occurrences_on_project_recurrence_id"
  end

  create_table "project_recurrences", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "creator_id", null: false
    t.string "frequency", null: false
    t.date "anchor_on", null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_project_recurrences_on_creator_id"
    t.index ["project_id"], name: "index_project_recurrences_on_project_id", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.string "name", null: false
    t.text "description"
    t.date "starts_on"
    t.date "ends_on"
    t.bigint "owner_id", null: false
    t.boolean "open_team", default: false, null: false
    t.string "public_token"
    t.string "enabled_tools", default: [], null: false, array: true
    t.datetime "done_at"
    t.datetime "archived_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.float "banner_focus_x", default: 0.5, null: false
    t.float "banner_focus_y", default: 0.5, null: false
    t.boolean "banner_focus_manual", default: false, null: false
    t.string "banner_alt_text"
    t.string "skills_needed", default: [], null: false, array: true
    t.index ["organization_id"], name: "index_projects_on_organization_id"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
    t.index ["public_token"], name: "index_projects_on_public_token", unique: true
  end

  create_table "recipients", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_recipients_on_person_id"
    t.index ["project_id", "person_id"], name: "index_recipients_on_project_id_and_person_id", unique: true
    t.index ["project_id"], name: "index_recipients_on_project_id"
  end

  create_table "schedule_items", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.date "date", null: false
    t.time "starts_at_time"
    t.time "ends_at_time"
    t.string "title", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_schedule_items_on_project_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_sessions_on_person_id"
  end

  create_table "slot_claims", force: :cascade do |t|
    t.bigint "slot_id", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_slot_claims_on_person_id"
    t.index ["slot_id", "person_id"], name: "index_slot_claims_on_slot_id_and_person_id", unique: true
    t.index ["slot_id"], name: "index_slot_claims_on_slot_id"
  end

  create_table "slots", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.date "date", null: false
    t.time "starts_at_time"
    t.string "label", null: false
    t.integer "capacity", default: 1, null: false
    t.integer "claims_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_slots_on_project_id"
    t.check_constraint "capacity >= 1", name: "slots_capacity_at_least_one"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.string "title", null: false
    t.date "due_on"
    t.bigint "assignee_id"
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id", "completed_at", "due_on"], name: "index_tasks_on_assignee_id_and_completed_at_and_due_on"
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["completed_by_id"], name: "index_tasks_on_completed_by_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
  end

  create_table "unavailabilities", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "person_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_unavailabilities_on_organization_id"
    t.index ["person_id"], name: "index_unavailabilities_on_person_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "budget_lines", "people", column: "responsible_person_id"
  add_foreign_key "budget_lines", "projects"
  add_foreign_key "check_ins", "organizations"
  add_foreign_key "check_ins", "people"
  add_foreign_key "check_ins", "people", column: "checked_in_by_id"
  add_foreign_key "comments", "people", column: "author_id"
  add_foreign_key "doc_items", "people", column: "author_id"
  add_foreign_key "doc_items", "projects"
  add_foreign_key "follows", "people"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "people"
  add_foreign_key "invitations", "people", column: "inviter_id"
  add_foreign_key "invitations", "projects"
  add_foreign_key "list_columns", "lists"
  add_foreign_key "list_rows", "lists"
  add_foreign_key "lists", "projects"
  add_foreign_key "memberships", "people"
  add_foreign_key "memberships", "projects"
  add_foreign_key "mentions", "people"
  add_foreign_key "messages", "messages", column: "parent_id"
  add_foreign_key "messages", "people", column: "author_id"
  add_foreign_key "messages", "projects"
  add_foreign_key "notes", "organizations"
  add_foreign_key "notes", "people", column: "author_id"
  add_foreign_key "notifications", "people", column: "actor_id"
  add_foreign_key "notifications", "people", column: "recipient_id"
  add_foreign_key "people", "organizations"
  add_foreign_key "planner_sessions", "people", column: "started_by_id"
  add_foreign_key "planner_sessions", "projects"
  add_foreign_key "project_debriefs", "projects"
  add_foreign_key "project_occurrences", "project_recurrences"
  add_foreign_key "project_occurrences", "projects", on_delete: :nullify
  add_foreign_key "project_recurrences", "people", column: "creator_id"
  add_foreign_key "project_recurrences", "projects"
  add_foreign_key "projects", "organizations"
  add_foreign_key "projects", "people", column: "owner_id"
  add_foreign_key "recipients", "people"
  add_foreign_key "recipients", "projects"
  add_foreign_key "schedule_items", "projects"
  add_foreign_key "sessions", "people"
  add_foreign_key "slot_claims", "people"
  add_foreign_key "slot_claims", "slots"
  add_foreign_key "slots", "projects"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tasks", "people", column: "assignee_id"
  add_foreign_key "tasks", "people", column: "completed_by_id"
  add_foreign_key "tasks", "projects"
  add_foreign_key "unavailabilities", "organizations"
  add_foreign_key "unavailabilities", "people"
end
