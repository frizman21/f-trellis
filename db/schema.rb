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

ActiveRecord::Schema[8.1].define(version: 2026_08_19_213528) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "domains", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "host", null: false
    t.integer "min_crawl_delay_seconds"
    t.integer "robots_crawl_delay_seconds"
    t.datetime "robots_fetched_at"
    t.string "robots_status"
    t.text "robots_txt"
    t.datetime "updated_at", null: false
    t.index ["host"], name: "index_domains_on_host", unique: true
  end

  create_table "entities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "entity_type_id", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_entities_on_kept", where: "(deleted_at IS NULL)"
    t.index ["entity_type_id"], name: "index_entities_on_entity_type_id"
    t.index ["project_id"], name: "index_entities_on_project_id"
  end

  create_table "entity_attribute_value_sources", force: :cascade do |t|
    t.integer "confidence", default: 100, null: false
    t.datetime "created_at", null: false
    t.bigint "entity_attribute_value_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_attribute_value_id", "source_id"], name: "index_entity_attribute_value_sources_on_owner_and_source", unique: true
    t.index ["entity_attribute_value_id"], name: "idx_on_entity_attribute_value_id_36db6dab02"
    t.index ["source_id"], name: "index_entity_attribute_value_sources_on_source_id"
  end

  create_table "entity_attribute_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "datetime_value"
    t.bigint "entity_id", null: false
    t.bigint "entity_type_attribute_id", null: false
    t.float "float_value"
    t.integer "int_value"
    t.bigint "project_id", null: false
    t.string "string_value"
    t.datetime "updated_at", null: false
    t.index ["entity_id", "entity_type_attribute_id"], name: "index_entity_attribute_values_on_entity_and_attribute", unique: true
    t.index ["entity_id"], name: "index_entity_attribute_values_on_entity_id"
    t.index ["entity_type_attribute_id"], name: "index_entity_attribute_values_on_entity_type_attribute_id"
    t.index ["project_id"], name: "index_entity_attribute_values_on_project_id"
  end

  create_table "entity_sources", force: :cascade do |t|
    t.integer "confidence", default: 100, null: false
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "source_id"], name: "index_entity_sources_on_owner_and_source", unique: true
    t.index ["entity_id"], name: "index_entity_sources_on_entity_id"
    t.index ["source_id"], name: "index_entity_sources_on_source_id"
  end

  create_table "entity_type_attributes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_type_id", null: false
    t.boolean "is_disabled", default: false, null: false
    t.boolean "is_displayed_on_index", default: true, null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.string "value_type", null: false
    t.index ["entity_type_id", "name"], name: "index_entity_type_attributes_on_type_and_name", unique: true
    t.index ["entity_type_id"], name: "index_entity_type_attributes_on_entity_type_id"
    t.index ["project_id"], name: "index_entity_type_attributes_on_project_id"
  end

  create_table "entity_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index "project_id, lower((name)::text)", name: "index_entity_types_on_project_and_lower_name", unique: true
    t.index ["project_id"], name: "index_entity_types_on_project_id"
  end

  create_table "extraction_runs", force: :cascade do |t|
    t.bigint "chat_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "model_id", null: false
    t.bigint "project_id", null: false
    t.text "response"
    t.bigint "source_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.jsonb "summary", default: {}, null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_extraction_runs_on_chat_id"
    t.index ["model_id"], name: "index_extraction_runs_on_model_id"
    t.index ["project_id", "source_id", "status"], name: "index_extraction_runs_on_project_source_status"
    t.index ["project_id"], name: "index_extraction_runs_on_project_id"
    t.index ["source_id", "created_at"], name: "index_extraction_runs_on_source_id_and_created_at"
    t.index ["source_id"], name: "index_extraction_runs_on_source_id"
  end

  create_table "fetch_records", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "domain_id", null: false
    t.string "outcome", default: "ok", null: false
    t.integer "status_code"
    t.string "trigger", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["created_at"], name: "index_fetch_records_on_created_at"
    t.index ["domain_id"], name: "index_fetch_records_on_domain_id"
    t.index ["outcome"], name: "index_fetch_records_on_outcome"
    t.index ["trigger"], name: "index_fetch_records_on_trigger"
    t.index ["url"], name: "index_fetch_records_on_url"
  end

  create_table "learning_set_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "learning_set_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["learning_set_id", "source_id"], name: "index_learning_set_sources_on_pair", unique: true
    t.index ["learning_set_id"], name: "index_learning_set_sources_on_learning_set_id"
    t.index ["source_id"], name: "index_learning_set_sources_on_source_id"
  end

  create_table "learning_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_learning_sets_on_name", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.bigint "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.bigint "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.bigint "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "model_endpoints", force: :cascade do |t|
    t.string "api_key_env_var"
    t.string "base_url", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_model_endpoints_on_name", unique: true
  end

  create_table "models", force: :cascade do |t|
    t.jsonb "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.boolean "is_deprecated", default: false, null: false
    t.boolean "is_disabled", default: false, null: false
    t.date "knowledge_cutoff"
    t.datetime "last_seen_at"
    t.integer "max_output_tokens"
    t.jsonb "metadata", default: {}
    t.jsonb "modalities", default: {}
    t.datetime "model_created_at"
    t.bigint "model_endpoint_id"
    t.string "model_id", null: false
    t.string "name", null: false
    t.jsonb "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["capabilities"], name: "index_models_on_capabilities", using: :gin
    t.index ["family"], name: "index_models_on_family"
    t.index ["is_deprecated", "is_disabled"], name: "index_models_on_is_deprecated_and_is_disabled"
    t.index ["last_seen_at"], name: "index_models_on_last_seen_at"
    t.index ["modalities"], name: "index_models_on_modalities", using: :gin
    t.index ["model_endpoint_id"], name: "index_models_on_model_endpoint_id"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "project_sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "source_id"], name: "index_project_sources_on_project_and_source", unique: true
    t.index ["project_id"], name: "index_project_sources_on_project_id"
    t.index ["source_id"], name: "index_project_sources_on_source_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "default_model_id"
    t.integer "extraction_attempts", default: 1, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["default_model_id"], name: "index_projects_on_default_model_id"
  end

  create_table "relationship_sources", force: :cascade do |t|
    t.integer "confidence", default: 100, null: false
    t.datetime "created_at", null: false
    t.bigint "relationship_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_id", "source_id"], name: "index_relationship_sources_on_owner_and_source", unique: true
    t.index ["relationship_id"], name: "index_relationship_sources_on_relationship_id"
    t.index ["source_id"], name: "index_relationship_sources_on_source_id"
  end

  create_table "relationship_type_attributes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_disabled", default: false, null: false
    t.boolean "is_displayed_on_index", default: true, null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.bigint "relationship_type_id", null: false
    t.datetime "updated_at", null: false
    t.string "value_type", null: false
    t.index ["project_id"], name: "index_relationship_type_attributes_on_project_id"
    t.index ["relationship_type_id", "name"], name: "index_relationship_type_attributes_on_type_and_name", unique: true
    t.index ["relationship_type_id"], name: "index_relationship_type_attributes_on_relationship_type_id"
  end

  create_table "relationship_type_value_sources", force: :cascade do |t|
    t.integer "confidence", default: 100, null: false
    t.datetime "created_at", null: false
    t.bigint "relationship_type_value_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["relationship_type_value_id", "source_id"], name: "index_relationship_type_value_sources_on_owner_and_source", unique: true
    t.index ["relationship_type_value_id"], name: "idx_on_relationship_type_value_id_3df863f22b"
    t.index ["source_id"], name: "index_relationship_type_value_sources_on_source_id"
  end

  create_table "relationship_type_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "datetime_value"
    t.float "float_value"
    t.integer "int_value"
    t.bigint "project_id", null: false
    t.bigint "relationship_id", null: false
    t.bigint "relationship_type_attribute_id", null: false
    t.string "string_value"
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_relationship_type_values_on_project_id"
    t.index ["relationship_id", "relationship_type_attribute_id"], name: "index_relationship_type_values_on_relationship_and_attribute", unique: true
    t.index ["relationship_id"], name: "index_relationship_type_values_on_relationship_id"
    t.index ["relationship_type_attribute_id"], name: "idx_on_relationship_type_attribute_id_bac6f1f974"
  end

  create_table "relationship_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "from_entity_type_id", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.bigint "to_entity_type_id", null: false
    t.datetime "updated_at", null: false
    t.index "project_id, lower((name)::text)", name: "index_relationship_types_on_project_and_lower_name", unique: true
    t.index ["from_entity_type_id"], name: "index_relationship_types_on_from_entity_type_id"
    t.index ["project_id"], name: "index_relationship_types_on_project_id"
    t.index ["to_entity_type_id"], name: "index_relationship_types_on_to_entity_type_id"
  end

  create_table "relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.bigint "from_entity_id", null: false
    t.bigint "project_id", null: false
    t.bigint "relationship_type_id", null: false
    t.bigint "to_entity_id", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_relationships_on_kept", where: "(deleted_at IS NULL)"
    t.index ["from_entity_id"], name: "index_relationships_on_from_entity_id"
    t.index ["project_id"], name: "index_relationships_on_project_id"
    t.index ["relationship_type_id"], name: "index_relationships_on_relationship_type_id"
    t.index ["to_entity_id"], name: "index_relationships_on_to_entity_id"
  end

  create_table "research_starting_points", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "frequency", null: false
    t.boolean "is_enabled", default: true, null: false
    t.datetime "last_run_at"
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["frequency"], name: "index_research_starting_points_on_frequency"
    t.index ["is_enabled"], name: "index_research_starting_points_on_is_enabled"
  end

  create_table "skill_evaluation_models", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "model_id", null: false
    t.bigint "skill_evaluation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_skill_evaluation_models_on_model_id"
    t.index ["skill_evaluation_id", "model_id"], name: "index_skill_evaluation_models_on_pair", unique: true
    t.index ["skill_evaluation_id"], name: "index_skill_evaluation_models_on_skill_evaluation_id"
  end

  create_table "skill_evaluation_results", force: :cascade do |t|
    t.bigint "chat_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "model_id", null: false
    t.string "proposal_digest"
    t.jsonb "proposals", default: [], null: false
    t.text "response"
    t.decimal "score", precision: 6, scale: 3
    t.bigint "skill_evaluation_id", null: false
    t.bigint "skill_revision_id", null: false
    t.bigint "source_id", null: false
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_skill_evaluation_results_on_chat_id"
    t.index ["model_id"], name: "index_skill_evaluation_results_on_model_id"
    t.index ["proposal_digest"], name: "index_skill_evaluation_results_on_proposal_digest"
    t.index ["skill_evaluation_id", "source_id", "model_id", "skill_revision_id"], name: "index_skill_evaluation_results_on_run", unique: true
    t.index ["skill_evaluation_id"], name: "index_skill_evaluation_results_on_skill_evaluation_id"
    t.index ["skill_revision_id"], name: "index_skill_evaluation_results_on_skill_revision_id"
    t.index ["source_id"], name: "index_skill_evaluation_results_on_source_id"
  end

  create_table "skill_evaluations", force: :cascade do |t|
    t.bigint "base_model_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "learning_set_id", null: false
    t.string "model_objective"
    t.string "name", null: false
    t.bigint "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["base_model_id"], name: "index_skill_evaluations_on_base_model_id"
    t.index ["learning_set_id"], name: "index_skill_evaluations_on_learning_set_id"
    t.index ["skill_id"], name: "index_skill_evaluations_on_skill_id"
  end

  create_table "skill_revisions", force: :cascade do |t|
    t.string "content"
    t.datetime "created_at", null: false
    t.bigint "model_id"
    t.integer "sequence", default: 0, null: false
    t.bigint "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_skill_revisions_on_model_id"
    t.index ["skill_id", "sequence"], name: "index_skill_revisions_on_skill_id_and_sequence", unique: true
    t.index ["skill_id"], name: "index_skill_revisions_on_skill_id"
  end

  create_table "skills", force: :cascade do |t|
    t.text "applicability"
    t.datetime "created_at", null: false
    t.boolean "is_active", default: false, null: false
    t.boolean "is_fixtured", default: false, null: false
    t.boolean "is_promotable", default: false, null: false
    t.string "name"
    t.bigint "preferred_model_id"
    t.string "purpose"
    t.datetime "updated_at", null: false
    t.text "url_patterns", default: [], null: false, array: true
    t.index ["is_promotable", "is_fixtured"], name: "index_skills_on_is_promotable_and_is_fixtured"
    t.index ["preferred_model_id"], name: "index_skills_on_preferred_model_id"
  end

  create_table "source_data", force: :cascade do |t|
    t.string "content_hash"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.binary "data"
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["content_hash"], name: "index_source_data_on_content_hash"
    t.index ["source_id"], name: "index_source_data_on_source_id"
  end

  create_table "source_exclusions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "is_enabled", default: true, null: false
    t.string "pattern", null: false
    t.datetime "updated_at", null: false
    t.index ["pattern"], name: "index_source_exclusions_on_pattern", unique: true
  end

  create_table "source_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_count", default: 0, null: false
    t.text "error_message"
    t.integer "existing_count", default: 0, null: false
    t.text "raw_urls", null: false
    t.jsonb "rejected", default: [], null: false
    t.string "status", default: "new", null: false
    t.integer "submitted_count", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "source_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "from_source_id", null: false
    t.bigint "source_datum_id"
    t.bigint "to_source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["from_source_id", "to_source_id"], name: "index_source_links_on_from_source_id_and_to_source_id", unique: true
    t.index ["from_source_id"], name: "index_source_links_on_from_source_id"
    t.index ["source_datum_id"], name: "index_source_links_on_source_datum_id"
    t.index ["to_source_id"], name: "index_source_links_on_to_source_id"
  end

  create_table "source_processing_reports", force: :cascade do |t|
    t.bigint "chat_id"
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.text "error"
    t.jsonb "facts", default: {}, null: false
    t.bigint "model_id"
    t.bigint "skill_revision_id", null: false
    t.bigint "source_id", null: false
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_source_processing_reports_on_chat_id"
    t.index ["model_id"], name: "index_source_processing_reports_on_model_id"
    t.index ["skill_revision_id"], name: "index_source_processing_reports_on_skill_revision_id"
    t.index ["source_id", "skill_revision_id", "content_hash"], name: "index_reports_on_source_skill_revision_and_content", unique: true
    t.index ["source_id"], name: "index_source_processing_reports_on_source_id"
    t.index ["status"], name: "index_source_processing_reports_on_status"
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.bigint "domain_id", null: false
    t.string "etag"
    t.boolean "is_fixtured", default: false, null: false
    t.boolean "is_noindex", default: false, null: false
    t.boolean "is_promotable", default: false, null: false
    t.datetime "last_modified_at"
    t.bigint "parent_source_id"
    t.string "resolved_url"
    t.datetime "sitemap_lastmod_at"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["domain_id"], name: "index_sources_on_domain_id"
    t.index ["is_noindex"], name: "index_sources_on_is_noindex"
    t.index ["is_promotable", "is_fixtured"], name: "index_sources_on_is_promotable_and_is_fixtured"
    t.index ["parent_source_id"], name: "index_sources_on_parent_source_id"
    t.index ["status"], name: "index_sources_on_status"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.jsonb "arguments", default: {}
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "triage_configurations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instructions"
    t.bigint "model_id"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_triage_configurations_on_model_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.boolean "read_only", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "models"
  add_foreign_key "entities", "entity_types"
  add_foreign_key "entities", "projects"
  add_foreign_key "entity_attribute_value_sources", "entity_attribute_values"
  add_foreign_key "entity_attribute_value_sources", "sources"
  add_foreign_key "entity_attribute_values", "entities"
  add_foreign_key "entity_attribute_values", "entity_type_attributes"
  add_foreign_key "entity_attribute_values", "projects"
  add_foreign_key "entity_sources", "entities"
  add_foreign_key "entity_sources", "sources"
  add_foreign_key "entity_type_attributes", "entity_types"
  add_foreign_key "entity_type_attributes", "projects"
  add_foreign_key "entity_types", "projects"
  add_foreign_key "extraction_runs", "chats"
  add_foreign_key "extraction_runs", "models"
  add_foreign_key "extraction_runs", "projects"
  add_foreign_key "extraction_runs", "sources"
  add_foreign_key "fetch_records", "domains"
  add_foreign_key "learning_set_sources", "learning_sets", on_delete: :cascade
  add_foreign_key "learning_set_sources", "sources"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "models", "model_endpoints"
  add_foreign_key "project_sources", "projects"
  add_foreign_key "project_sources", "sources"
  add_foreign_key "projects", "models", column: "default_model_id"
  add_foreign_key "relationship_sources", "relationships"
  add_foreign_key "relationship_sources", "sources"
  add_foreign_key "relationship_type_attributes", "projects"
  add_foreign_key "relationship_type_attributes", "relationship_types"
  add_foreign_key "relationship_type_value_sources", "relationship_type_values"
  add_foreign_key "relationship_type_value_sources", "sources"
  add_foreign_key "relationship_type_values", "projects"
  add_foreign_key "relationship_type_values", "relationship_type_attributes"
  add_foreign_key "relationship_type_values", "relationships"
  add_foreign_key "relationship_types", "entity_types", column: "from_entity_type_id"
  add_foreign_key "relationship_types", "entity_types", column: "to_entity_type_id"
  add_foreign_key "relationship_types", "projects"
  add_foreign_key "relationships", "entities", column: "from_entity_id"
  add_foreign_key "relationships", "entities", column: "to_entity_id"
  add_foreign_key "relationships", "projects"
  add_foreign_key "relationships", "relationship_types"
  add_foreign_key "skill_evaluation_models", "models"
  add_foreign_key "skill_evaluation_models", "skill_evaluations", on_delete: :cascade
  add_foreign_key "skill_evaluation_results", "chats"
  add_foreign_key "skill_evaluation_results", "models"
  add_foreign_key "skill_evaluation_results", "skill_evaluations", on_delete: :cascade
  add_foreign_key "skill_evaluation_results", "skill_revisions"
  add_foreign_key "skill_evaluation_results", "sources"
  add_foreign_key "skill_evaluations", "learning_sets"
  add_foreign_key "skill_evaluations", "models", column: "base_model_id"
  add_foreign_key "skill_evaluations", "skills"
  add_foreign_key "skill_revisions", "models"
  add_foreign_key "skill_revisions", "skills"
  add_foreign_key "skills", "models", column: "preferred_model_id"
  add_foreign_key "source_data", "sources"
  add_foreign_key "source_links", "source_data"
  add_foreign_key "source_links", "sources", column: "from_source_id", on_delete: :cascade
  add_foreign_key "source_links", "sources", column: "to_source_id", on_delete: :cascade
  add_foreign_key "source_processing_reports", "chats"
  add_foreign_key "source_processing_reports", "models"
  add_foreign_key "source_processing_reports", "skill_revisions"
  add_foreign_key "source_processing_reports", "sources"
  add_foreign_key "sources", "domains"
  add_foreign_key "sources", "sources", column: "parent_source_id", on_delete: :nullify
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "triage_configurations", "models"
end
