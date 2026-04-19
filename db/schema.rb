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

ActiveRecord::Schema[8.1].define(version: 2026_04_19_010010) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "person_types", force: :cascade do |t|
    t.text "additional_attribute_keys", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_person_types_on_name", unique: true
  end

  create_table "skill_revisions", force: :cascade do |t|
    t.string "content"
    t.datetime "created_at", null: false
    t.integer "sequence", default: 0, null: false
    t.bigint "skill_id", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id", "sequence"], name: "index_skill_revisions_on_skill_id_and_sequence", unique: true
    t.index ["skill_id"], name: "index_skill_revisions_on_skill_id"
  end

  create_table "skills", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_active", default: false, null: false
    t.string "name"
    t.string "purpose"
    t.datetime "updated_at", null: false
  end

  create_table "source_data", force: :cascade do |t|
    t.string "content_type"
    t.datetime "created_at", null: false
    t.binary "data"
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_source_data_on_source_id"
  end

  create_table "source_processing_reports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "facts", default: {}, null: false
    t.bigint "skill_revision_id", null: false
    t.bigint "source_id", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_revision_id"], name: "index_source_processing_reports_on_skill_revision_id"
    t.index ["source_id"], name: "index_source_processing_reports_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "status", default: "new", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["status"], name: "index_sources_on_status"
  end

  add_foreign_key "facilities", "facility_details", column: "current_detail_id"
  add_foreign_key "facility_detail_facility_types", "facility_details"
  add_foreign_key "facility_detail_facility_types", "facility_types"
  add_foreign_key "facility_details", "facilities"
  add_foreign_key "facility_details", "source_processing_reports"
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
  add_foreign_key "organizations", "organization_details", column: "current_detail_id"
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
  add_foreign_key "skill_revisions", "skills"
  add_foreign_key "source_data", "sources"
  add_foreign_key "source_processing_reports", "skill_revisions"
  add_foreign_key "source_processing_reports", "sources"
end
