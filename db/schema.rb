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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_130029) do
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

  create_table "contract_detail_contract_types", force: :cascade do |t|
    t.bigint "contract_detail_id", null: false
    t.bigint "contract_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_detail_id", "contract_type_id"], name: "index_cdct_on_detail_and_type", unique: true
    t.index ["contract_detail_id"], name: "index_cdct_on_detail_id"
    t.index ["contract_type_id"], name: "index_cdct_on_type_id"
  end

  create_table "contract_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "identifier", null: false
    t.bigint "source_processing_report_id", null: false
    t.date "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
    t.decimal "value_usd", precision: 15, scale: 2
    t.index ["contract_id"], name: "index_contract_details_on_contract_id"
    t.index ["source_processing_report_id"], name: "index_contract_details_on_source_processing_report_id"
  end

  create_table "contract_organization_detail_contract_organization_types", force: :cascade do |t|
    t.bigint "contract_organization_detail_id", null: false
    t.bigint "contract_organization_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_organization_detail_id", "contract_organization_type_id"], name: "index_codcot_on_pair", unique: true
    t.index ["contract_organization_detail_id"], name: "index_codcot_on_detail_id"
    t.index ["contract_organization_type_id"], name: "index_codcot_on_type_id"
  end

  create_table "contract_organization_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.bigint "contract_organization_id", null: false
    t.datetime "created_at", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_organization_id"], name: "index_cod_on_contract_organization_id"
    t.index ["source_processing_report_id"], name: "index_cod_on_source_processing_report_id"
  end

  create_table "contract_organization_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contract_organization_types_on_name", unique: true
  end

  create_table "contract_organizations", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id", "organization_id"], name: "index_co_on_pair", unique: true
    t.index ["contract_id"], name: "index_contract_organizations_on_contract_id"
    t.index ["current_detail_id"], name: "index_contract_organizations_on_current_detail_id"
    t.index ["organization_id"], name: "index_contract_organizations_on_organization_id"
  end

  create_table "contract_part_detail_contract_part_types", force: :cascade do |t|
    t.bigint "contract_part_detail_id", null: false
    t.bigint "contract_part_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_part_detail_id", "contract_part_type_id"], name: "index_cptdcptt_on_pair", unique: true
    t.index ["contract_part_detail_id"], name: "index_cptdcptt_on_detail_id"
    t.index ["contract_part_type_id"], name: "index_cptdcptt_on_type_id"
  end

  create_table "contract_part_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.bigint "contract_part_id", null: false
    t.datetime "created_at", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_part_id"], name: "index_cptd_on_contract_part_id"
    t.index ["source_processing_report_id"], name: "index_cptd_on_source_processing_report_id"
  end

  create_table "contract_part_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contract_part_types_on_name", unique: true
  end

  create_table "contract_parts", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "part_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id", "part_id"], name: "index_cpt_on_pair", unique: true
    t.index ["contract_id"], name: "index_contract_parts_on_contract_id"
    t.index ["current_detail_id"], name: "index_contract_parts_on_current_detail_id"
    t.index ["part_id"], name: "index_contract_parts_on_part_id"
  end

  create_table "contract_people", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id", "person_id"], name: "index_cps_on_pair", unique: true
    t.index ["contract_id"], name: "index_contract_people_on_contract_id"
    t.index ["current_detail_id"], name: "index_contract_people_on_current_detail_id"
    t.index ["person_id"], name: "index_contract_people_on_person_id"
  end

  create_table "contract_person_detail_contract_person_types", force: :cascade do |t|
    t.bigint "contract_person_detail_id", null: false
    t.bigint "contract_person_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_person_detail_id", "contract_person_type_id"], name: "index_cpsdcpst_on_pair", unique: true
    t.index ["contract_person_detail_id"], name: "index_cpsdcpst_on_detail_id"
    t.index ["contract_person_type_id"], name: "index_cpsdcpst_on_type_id"
  end

  create_table "contract_person_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.bigint "contract_person_id", null: false
    t.datetime "created_at", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_person_id"], name: "index_cpsd_on_contract_person_id"
    t.index ["source_processing_report_id"], name: "index_cpsd_on_source_processing_report_id"
  end

  create_table "contract_person_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contract_person_types_on_name", unique: true
  end

  create_table "contract_technologies", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_id", "technology_id"], name: "index_ct_on_pair", unique: true
    t.index ["contract_id"], name: "index_contract_technologies_on_contract_id"
    t.index ["current_detail_id"], name: "index_contract_technologies_on_current_detail_id"
    t.index ["technology_id"], name: "index_contract_technologies_on_technology_id"
  end

  create_table "contract_technology_detail_contract_technology_types", force: :cascade do |t|
    t.bigint "contract_technology_detail_id", null: false
    t.bigint "contract_technology_type_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_technology_detail_id", "contract_technology_type_id"], name: "index_ctdctt_on_pair", unique: true
    t.index ["contract_technology_detail_id"], name: "index_ctdctt_on_detail_id"
    t.index ["contract_technology_type_id"], name: "index_ctdctt_on_type_id"
  end

  create_table "contract_technology_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.bigint "contract_technology_id", null: false
    t.datetime "created_at", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["contract_technology_id"], name: "index_ctd_on_contract_technology_id"
    t.index ["source_processing_report_id"], name: "index_ctd_on_source_processing_report_id"
  end

  create_table "contract_technology_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contract_technology_types_on_name", unique: true
  end

  create_table "contract_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contract_types_on_name", unique: true
  end

  create_table "contracts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_contracts_on_current_detail_id"
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

  create_table "facilities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_facilities_on_current_detail_id"
  end

  create_table "facility_detail_facility_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "facility_detail_id", null: false
    t.bigint "facility_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["facility_detail_id", "facility_type_id"], name: "index_fdft_on_detail_and_type", unique: true
    t.index ["facility_detail_id"], name: "index_facility_detail_facility_types_on_facility_detail_id"
    t.index ["facility_type_id"], name: "index_facility_detail_facility_types_on_facility_type_id"
  end

  create_table "facility_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.string "address", null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "facility_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["facility_id"], name: "index_facility_details_on_facility_id"
    t.index ["source_processing_report_id"], name: "index_facility_details_on_source_processing_report_id"
  end

  create_table "facility_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_facility_types_on_name", unique: true
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
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "org_org_typings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_organization_detail_id", null: false
    t.bigint "organization_organization_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_organization_detail_id", "organization_organization_type_id"], name: "index_org_org_typings_on_pair", unique: true
    t.index ["organization_organization_detail_id"], name: "index_org_org_typings_on_detail_id"
    t.index ["organization_organization_type_id"], name: "index_org_org_typings_on_type_id"
  end

  create_table "organization_detail_organization_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_detail_id", null: false
    t.bigint "organization_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_detail_id", "organization_type_id"], name: "index_odot_on_detail_and_type", unique: true
    t.index ["organization_detail_id"], name: "idx_on_organization_detail_id_f963e63125"
    t.index ["organization_type_id"], name: "idx_on_organization_type_id_d221367eaf"
  end

  create_table "organization_details", force: :cascade do |t|
    t.string "acronym"
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_organization_details_on_organization_id"
    t.index ["source_processing_report_id"], name: "index_organization_details_on_source_processing_report_id"
  end

  create_table "organization_organization_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "organization_organization_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_organization_id"], name: "index_oo_details_on_oo_id"
    t.index ["source_processing_report_id"], name: "index_oo_details_on_spr_id"
  end

  create_table "organization_organization_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_org_org_types_on_name", unique: true
  end

  create_table "organization_organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "organization_a_id", null: false
    t.bigint "organization_b_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_oo_on_current_detail"
    t.index ["organization_a_id", "organization_b_id"], name: "index_org_orgs_on_a_and_b", unique: true
    t.index ["organization_a_id"], name: "index_organization_organizations_on_organization_a_id"
    t.index ["organization_b_id"], name: "index_organization_organizations_on_organization_b_id"
  end

  create_table "organization_research_runs", force: :cascade do |t|
    t.jsonb "candidates", default: [], null: false
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "organization_id", null: false
    t.integer "pages_crawled", default: 0, null: false
    t.integer "reports_queued", default: 0, null: false
    t.string "search_query"
    t.bigint "seed_source_id"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "created_at"], name: "idx_on_organization_id_created_at_ae8f96bcd5"
    t.index ["organization_id"], name: "index_organization_research_runs_on_organization_id"
    t.index ["seed_source_id"], name: "index_organization_research_runs_on_seed_source_id"
  end

  create_table "organization_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "organization_id", null: false
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_organization_technologies_on_current_detail_id"
    t.index ["organization_id", "technology_id"], name: "index_ot_on_pair", unique: true
    t.index ["organization_id"], name: "index_organization_technologies_on_organization_id"
    t.index ["technology_id"], name: "index_organization_technologies_on_technology_id"
  end

  create_table "organization_technology_detail_organization_technology_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_technology_detail_id", null: false
    t.bigint "organization_technology_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_technology_detail_id", "organization_technology_type_id"], name: "index_otdott_on_pair", unique: true
    t.index ["organization_technology_detail_id"], name: "index_otdott_on_detail_id"
    t.index ["organization_technology_type_id"], name: "index_otdott_on_type_id"
  end

  create_table "organization_technology_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "organization_technology_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_technology_id"], name: "index_otd_on_organization_technology_id"
    t.index ["source_processing_report_id"], name: "index_otd_on_source_processing_report_id"
  end

  create_table "organization_technology_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organization_technology_types_on_name", unique: true
  end

  create_table "organization_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organization_types_on_name", unique: true
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_organizations_on_current_detail_id"
  end

  create_table "part_detail_parameters", force: :cascade do |t|
    t.string "as_stated"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "part_detail_id", null: false
    t.bigint "part_type_parameter_id", null: false
    t.datetime "updated_at", null: false
    t.decimal "value_number", precision: 20, scale: 6
    t.string "value_text"
    t.index ["part_detail_id", "part_type_parameter_id"], name: "index_part_detail_parameters_on_detail_and_parameter", unique: true
    t.index ["part_detail_id"], name: "index_part_detail_parameters_on_part_detail_id"
    t.index ["part_type_parameter_id"], name: "index_part_detail_parameters_on_part_type_parameter_id"
  end

  create_table "part_detail_part_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "part_detail_id", null: false
    t.bigint "part_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_detail_id", "part_type_id"], name: "index_pdpt_part_on_detail_and_type", unique: true
    t.index ["part_detail_id"], name: "index_part_detail_part_types_on_part_detail_id"
    t.index ["part_type_id"], name: "index_part_detail_part_types_on_part_type_id"
  end

  create_table "part_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "part_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_id"], name: "index_part_details_on_part_id"
    t.index ["source_processing_report_id"], name: "index_part_details_on_source_processing_report_id"
  end

  create_table "part_organization_detail_part_organization_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "part_organization_detail_id", null: false
    t.bigint "part_organization_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_organization_detail_id", "part_organization_type_id"], name: "index_podpot_part_on_pair", unique: true
    t.index ["part_organization_detail_id"], name: "index_podpot_part_on_detail_id"
    t.index ["part_organization_type_id"], name: "index_podpot_part_on_type_id"
  end

  create_table "part_organization_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "part_organization_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_organization_id"], name: "index_part_organization_details_on_part_organization_id"
    t.index ["source_processing_report_id"], name: "index_part_organization_details_on_source_processing_report_id"
  end

  create_table "part_organization_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_part_organization_types_on_name", unique: true
  end

  create_table "part_organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "organization_id", null: false
    t.bigint "part_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_part_organizations_on_current_detail_id"
    t.index ["organization_id"], name: "index_part_organizations_on_organization_id"
    t.index ["part_id", "organization_id"], name: "index_part_organizations_on_part_id_and_organization_id", unique: true
    t.index ["part_id"], name: "index_part_organizations_on_part_id"
  end

  create_table "part_part_detail_part_part_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "part_part_detail_id", null: false
    t.bigint "part_part_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_part_detail_id", "part_part_type_id"], name: "index_ppdppt_part_on_pair", unique: true
    t.index ["part_part_detail_id"], name: "index_ppdppt_part_on_detail_id"
    t.index ["part_part_type_id"], name: "index_ppdppt_part_on_type_id"
  end

  create_table "part_part_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "part_part_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_part_id"], name: "index_part_part_details_on_part_part_id"
    t.index ["source_processing_report_id"], name: "index_part_part_details_on_source_processing_report_id"
  end

  create_table "part_part_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_part_part_types_on_name", unique: true
  end

  create_table "part_parts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "part_a_id", null: false
    t.bigint "part_b_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_part_parts_on_current_detail_id"
    t.index ["part_a_id", "part_b_id"], name: "index_part_parts_on_part_a_id_and_part_b_id", unique: true
    t.index ["part_a_id"], name: "index_part_parts_on_part_a_id"
    t.index ["part_b_id"], name: "index_part_parts_on_part_b_id"
  end

  create_table "part_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "part_id", null: false
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_part_technologies_on_current_detail_id"
    t.index ["part_id", "technology_id"], name: "index_part_technologies_on_part_id_and_technology_id", unique: true
    t.index ["part_id"], name: "index_part_technologies_on_part_id"
    t.index ["technology_id"], name: "index_part_technologies_on_technology_id"
  end

  create_table "part_technology_detail_part_technology_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "part_technology_detail_id", null: false
    t.bigint "part_technology_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_technology_detail_id", "part_technology_type_id"], name: "index_ptdptt_on_pair", unique: true
    t.index ["part_technology_detail_id"], name: "index_ptdptt_on_detail_id"
    t.index ["part_technology_type_id"], name: "index_ptdptt_on_type_id"
  end

  create_table "part_technology_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "part_technology_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["part_technology_id"], name: "index_part_technology_details_on_part_technology_id"
    t.index ["source_processing_report_id"], name: "index_ptd_on_source_processing_report_id"
  end

  create_table "part_technology_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_part_technology_types_on_name", unique: true
  end

  create_table "part_type_parameters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.bigint "part_type_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.string "value_type", default: "number", null: false
    t.index ["part_type_id", "name"], name: "index_part_type_parameters_on_type_and_name", unique: true
    t.index ["part_type_id"], name: "index_part_type_parameters_on_part_type_id"
  end

  create_table "part_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_part_types_on_name", unique: true
  end

  create_table "parts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_parts_on_current_detail_id"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_people_on_current_detail_id"
  end

  create_table "person_detail_person_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "person_detail_id", null: false
    t.bigint "person_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_detail_id", "person_type_id"], name: "index_pdpt_on_detail_and_type", unique: true
    t.index ["person_detail_id"], name: "index_person_detail_person_types_on_person_detail_id"
    t.index ["person_type_id"], name: "index_person_detail_person_types_on_person_type_id"
  end

  create_table "person_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.bigint "person_id", null: false
    t.bigint "source_processing_report_id"
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_person_details_on_person_id"
    t.index ["source_processing_report_id"], name: "index_person_details_on_source_processing_report_id"
  end

  create_table "person_organization_detail_person_organization_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "person_organization_detail_id", null: false
    t.bigint "person_organization_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_organization_detail_id", "person_organization_type_id"], name: "index_podpot_on_detail_and_type", unique: true
    t.index ["person_organization_detail_id"], name: "index_podpot_on_detail_id"
    t.index ["person_organization_type_id"], name: "index_podpot_on_type_id"
  end

  create_table "person_organization_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "person_organization_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_organization_id"], name: "index_person_organization_details_on_person_organization_id"
    t.index ["source_processing_report_id"], name: "idx_on_source_processing_report_id_9448e6535f"
  end

  create_table "person_organization_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_person_organization_types_on_name", unique: true
  end

  create_table "person_organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "organization_id", null: false
    t.bigint "person_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_person_organizations_on_current_detail_id"
    t.index ["organization_id"], name: "index_person_organizations_on_organization_id"
    t.index ["person_id", "organization_id"], name: "index_person_organizations_on_person_id_and_organization_id", unique: true
    t.index ["person_id"], name: "index_person_organizations_on_person_id"
  end

  create_table "person_people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "person_a_id", null: false
    t.bigint "person_b_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_person_people_on_current_detail_id"
    t.index ["person_a_id", "person_b_id"], name: "index_person_people_on_person_a_id_and_person_b_id", unique: true
    t.index ["person_a_id"], name: "index_person_people_on_person_a_id"
    t.index ["person_b_id"], name: "index_person_people_on_person_b_id"
  end

  create_table "person_person_detail_person_person_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "person_person_detail_id", null: false
    t.bigint "person_person_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_person_detail_id", "person_person_type_id"], name: "index_ppdppt_on_detail_and_type", unique: true
    t.index ["person_person_detail_id"], name: "index_ppdppt_on_detail_id"
    t.index ["person_person_type_id"], name: "index_ppdppt_on_type_id"
  end

  create_table "person_person_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "person_person_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_person_id"], name: "index_person_person_details_on_person_person_id"
    t.index ["source_processing_report_id"], name: "index_person_person_details_on_source_processing_report_id"
  end

  create_table "person_person_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_person_person_types_on_name", unique: true
  end

  create_table "person_science_detail_person_science_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "person_science_detail_id", null: false
    t.bigint "person_science_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_science_detail_id", "person_science_type_id"], name: "index_psdpst_on_pair", unique: true
    t.index ["person_science_detail_id"], name: "index_psdpst_on_detail_id"
    t.index ["person_science_type_id"], name: "index_psdpst_on_type_id"
  end

  create_table "person_science_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "person_science_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["person_science_id"], name: "index_person_science_details_on_person_science_id"
    t.index ["source_processing_report_id"], name: "index_psd_on_source_processing_report_id"
  end

  create_table "person_science_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_person_science_types_on_name", unique: true
  end

  create_table "person_sciences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "person_id", null: false
    t.bigint "science_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_person_sciences_on_current_detail_id"
    t.index ["person_id", "science_id"], name: "index_person_sciences_on_person_id_and_science_id", unique: true
    t.index ["person_id"], name: "index_person_sciences_on_person_id"
    t.index ["science_id"], name: "index_person_sciences_on_science_id"
  end

  create_table "person_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_person_types_on_name", unique: true
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

  create_table "science_detail_science_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "science_detail_id", null: false
    t.bigint "science_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["science_detail_id", "science_type_id"], name: "index_sdst_on_detail_and_type", unique: true
    t.index ["science_detail_id"], name: "index_science_detail_science_types_on_science_detail_id"
    t.index ["science_type_id"], name: "index_science_detail_science_types_on_science_type_id"
  end

  create_table "science_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "science_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["science_id"], name: "index_science_details_on_science_id"
    t.index ["source_processing_report_id"], name: "index_science_details_on_source_processing_report_id"
  end

  create_table "science_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.bigint "science_id", null: false
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_science_technologies_on_current_detail_id"
    t.index ["science_id", "technology_id"], name: "index_science_technologies_on_science_id_and_technology_id", unique: true
    t.index ["science_id"], name: "index_science_technologies_on_science_id"
    t.index ["technology_id"], name: "index_science_technologies_on_technology_id"
  end

  create_table "science_technology_detail_science_technology_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "science_technology_detail_id", null: false
    t.bigint "science_technology_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["science_technology_detail_id", "science_technology_type_id"], name: "index_stdstt_on_pair", unique: true
    t.index ["science_technology_detail_id"], name: "index_stdstt_on_detail_id"
    t.index ["science_technology_type_id"], name: "index_stdstt_on_type_id"
  end

  create_table "science_technology_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.bigint "science_technology_id", null: false
    t.bigint "source_processing_report_id", null: false
    t.datetime "updated_at", null: false
    t.index ["science_technology_id"], name: "index_std_on_science_technology_id"
    t.index ["source_processing_report_id"], name: "index_std_on_source_processing_report_id"
  end

  create_table "science_technology_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_science_technology_types_on_name", unique: true
  end

  create_table "science_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_science_types_on_name", unique: true
  end

  create_table "sciences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_sciences_on_current_detail_id"
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

  create_table "technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "current_detail_id"
    t.datetime "updated_at", null: false
    t.index ["current_detail_id"], name: "index_technologies_on_current_detail_id"
  end

  create_table "technology_detail_technology_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "technology_detail_id", null: false
    t.bigint "technology_type_id", null: false
    t.datetime "updated_at", null: false
    t.index ["technology_detail_id", "technology_type_id"], name: "index_tdtt_on_detail_and_type", unique: true
    t.index ["technology_detail_id"], name: "index_tdtt_on_detail_id"
    t.index ["technology_type_id"], name: "index_tdtt_on_type_id"
  end

  create_table "technology_details", force: :cascade do |t|
    t.jsonb "additional_attributes", default: {}, null: false
    t.datetime "as_of"
    t.integer "confidence_tenths"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "source_processing_report_id", null: false
    t.text "summary"
    t.bigint "technology_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_processing_report_id"], name: "index_technology_details_on_source_processing_report_id"
    t.index ["technology_id"], name: "index_technology_details_on_technology_id"
  end

  create_table "technology_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_technology_types_on_name", unique: true
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
  add_foreign_key "contract_detail_contract_types", "contract_details"
  add_foreign_key "contract_detail_contract_types", "contract_types"
  add_foreign_key "contract_details", "contracts"
  add_foreign_key "contract_details", "source_processing_reports"
  add_foreign_key "contract_organization_detail_contract_organization_types", "contract_organization_details"
  add_foreign_key "contract_organization_detail_contract_organization_types", "contract_organization_types"
  add_foreign_key "contract_organization_details", "contract_organizations"
  add_foreign_key "contract_organization_details", "source_processing_reports"
  add_foreign_key "contract_organizations", "contract_organization_details", column: "current_detail_id"
  add_foreign_key "contract_organizations", "contracts"
  add_foreign_key "contract_organizations", "organizations"
  add_foreign_key "contract_part_detail_contract_part_types", "contract_part_details"
  add_foreign_key "contract_part_detail_contract_part_types", "contract_part_types"
  add_foreign_key "contract_part_details", "contract_parts"
  add_foreign_key "contract_part_details", "source_processing_reports"
  add_foreign_key "contract_parts", "contract_part_details", column: "current_detail_id"
  add_foreign_key "contract_parts", "contracts"
  add_foreign_key "contract_parts", "parts"
  add_foreign_key "contract_people", "contract_person_details", column: "current_detail_id"
  add_foreign_key "contract_people", "contracts"
  add_foreign_key "contract_people", "people"
  add_foreign_key "contract_person_detail_contract_person_types", "contract_person_details"
  add_foreign_key "contract_person_detail_contract_person_types", "contract_person_types"
  add_foreign_key "contract_person_details", "contract_people"
  add_foreign_key "contract_person_details", "source_processing_reports"
  add_foreign_key "contract_technologies", "contract_technology_details", column: "current_detail_id"
  add_foreign_key "contract_technologies", "contracts"
  add_foreign_key "contract_technologies", "technologies"
  add_foreign_key "contract_technology_detail_contract_technology_types", "contract_technology_details"
  add_foreign_key "contract_technology_detail_contract_technology_types", "contract_technology_types"
  add_foreign_key "contract_technology_details", "contract_technologies"
  add_foreign_key "contract_technology_details", "source_processing_reports"
  add_foreign_key "contracts", "contract_details", column: "current_detail_id"
  add_foreign_key "facilities", "facility_details", column: "current_detail_id"
  add_foreign_key "facility_detail_facility_types", "facility_details"
  add_foreign_key "facility_detail_facility_types", "facility_types"
  add_foreign_key "facility_details", "facilities"
  add_foreign_key "facility_details", "source_processing_reports"
  add_foreign_key "fetch_records", "domains"
  add_foreign_key "learning_set_sources", "learning_sets", on_delete: :cascade
  add_foreign_key "learning_set_sources", "sources"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "org_org_typings", "organization_organization_details"
  add_foreign_key "org_org_typings", "organization_organization_types"
  add_foreign_key "organization_detail_organization_types", "organization_details"
  add_foreign_key "organization_detail_organization_types", "organization_types"
  add_foreign_key "organization_details", "organizations"
  add_foreign_key "organization_details", "source_processing_reports"
  add_foreign_key "organization_organization_details", "organization_organizations"
  add_foreign_key "organization_organization_details", "source_processing_reports"
  add_foreign_key "organization_organizations", "organization_organization_details", column: "current_detail_id"
  add_foreign_key "organization_organizations", "organizations", column: "organization_a_id"
  add_foreign_key "organization_organizations", "organizations", column: "organization_b_id"
  add_foreign_key "organization_research_runs", "organizations"
  add_foreign_key "organization_research_runs", "sources", column: "seed_source_id"
  add_foreign_key "organization_technologies", "organization_technology_details", column: "current_detail_id"
  add_foreign_key "organization_technologies", "organizations"
  add_foreign_key "organization_technologies", "technologies"
  add_foreign_key "organization_technology_detail_organization_technology_types", "organization_technology_details"
  add_foreign_key "organization_technology_detail_organization_technology_types", "organization_technology_types"
  add_foreign_key "organization_technology_details", "organization_technologies"
  add_foreign_key "organization_technology_details", "source_processing_reports"
  add_foreign_key "organizations", "organization_details", column: "current_detail_id"
  add_foreign_key "part_detail_parameters", "part_details"
  add_foreign_key "part_detail_parameters", "part_type_parameters"
  add_foreign_key "part_detail_part_types", "part_details"
  add_foreign_key "part_detail_part_types", "part_types"
  add_foreign_key "part_details", "parts"
  add_foreign_key "part_details", "source_processing_reports"
  add_foreign_key "part_organization_detail_part_organization_types", "part_organization_details"
  add_foreign_key "part_organization_detail_part_organization_types", "part_organization_types"
  add_foreign_key "part_organization_details", "part_organizations"
  add_foreign_key "part_organization_details", "source_processing_reports"
  add_foreign_key "part_organizations", "organizations"
  add_foreign_key "part_organizations", "part_organization_details", column: "current_detail_id"
  add_foreign_key "part_organizations", "parts"
  add_foreign_key "part_part_detail_part_part_types", "part_part_details"
  add_foreign_key "part_part_detail_part_part_types", "part_part_types"
  add_foreign_key "part_part_details", "part_parts"
  add_foreign_key "part_part_details", "source_processing_reports"
  add_foreign_key "part_parts", "part_part_details", column: "current_detail_id"
  add_foreign_key "part_parts", "parts", column: "part_a_id"
  add_foreign_key "part_parts", "parts", column: "part_b_id"
  add_foreign_key "part_technologies", "part_technology_details", column: "current_detail_id"
  add_foreign_key "part_technologies", "parts"
  add_foreign_key "part_technologies", "technologies"
  add_foreign_key "part_technology_detail_part_technology_types", "part_technology_details"
  add_foreign_key "part_technology_detail_part_technology_types", "part_technology_types"
  add_foreign_key "part_technology_details", "part_technologies"
  add_foreign_key "part_technology_details", "source_processing_reports"
  add_foreign_key "part_type_parameters", "part_types"
  add_foreign_key "parts", "part_details", column: "current_detail_id"
  add_foreign_key "people", "person_details", column: "current_detail_id"
  add_foreign_key "person_detail_person_types", "person_details"
  add_foreign_key "person_detail_person_types", "person_types"
  add_foreign_key "person_details", "people"
  add_foreign_key "person_details", "source_processing_reports"
  add_foreign_key "person_organization_detail_person_organization_types", "person_organization_details"
  add_foreign_key "person_organization_detail_person_organization_types", "person_organization_types"
  add_foreign_key "person_organization_details", "person_organizations"
  add_foreign_key "person_organization_details", "source_processing_reports"
  add_foreign_key "person_organizations", "organizations"
  add_foreign_key "person_organizations", "people"
  add_foreign_key "person_organizations", "person_organization_details", column: "current_detail_id"
  add_foreign_key "person_people", "people", column: "person_a_id"
  add_foreign_key "person_people", "people", column: "person_b_id"
  add_foreign_key "person_people", "person_person_details", column: "current_detail_id"
  add_foreign_key "person_person_detail_person_person_types", "person_person_details"
  add_foreign_key "person_person_detail_person_person_types", "person_person_types"
  add_foreign_key "person_person_details", "person_people"
  add_foreign_key "person_person_details", "source_processing_reports"
  add_foreign_key "person_science_detail_person_science_types", "person_science_details"
  add_foreign_key "person_science_detail_person_science_types", "person_science_types"
  add_foreign_key "person_science_details", "person_sciences"
  add_foreign_key "person_science_details", "source_processing_reports"
  add_foreign_key "person_sciences", "people"
  add_foreign_key "person_sciences", "person_science_details", column: "current_detail_id"
  add_foreign_key "person_sciences", "sciences"
  add_foreign_key "science_detail_science_types", "science_details"
  add_foreign_key "science_detail_science_types", "science_types"
  add_foreign_key "science_details", "sciences"
  add_foreign_key "science_details", "source_processing_reports"
  add_foreign_key "science_technologies", "science_technology_details", column: "current_detail_id"
  add_foreign_key "science_technologies", "sciences"
  add_foreign_key "science_technologies", "technologies"
  add_foreign_key "science_technology_detail_science_technology_types", "science_technology_details"
  add_foreign_key "science_technology_detail_science_technology_types", "science_technology_types"
  add_foreign_key "science_technology_details", "science_technologies"
  add_foreign_key "science_technology_details", "source_processing_reports"
  add_foreign_key "sciences", "science_details", column: "current_detail_id"
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
  add_foreign_key "technologies", "technology_details", column: "current_detail_id"
  add_foreign_key "technology_detail_technology_types", "technology_details"
  add_foreign_key "technology_detail_technology_types", "technology_types"
  add_foreign_key "technology_details", "source_processing_reports"
  add_foreign_key "technology_details", "technologies"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "triage_configurations", "models"
end
