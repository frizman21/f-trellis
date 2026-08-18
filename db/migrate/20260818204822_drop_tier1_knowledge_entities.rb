# Drops the tier 1 knowledge entity schema: the seven entities, their versioned
# detail records, their type taxonomies, and the thirteen relationships among
# them. See change request #4.
#
# Also drops organization_research_runs, an orphan that had no model, controller,
# or reference anywhere but the schema file.
#
# force: :cascade rather than hand-ordering 83 drops against their foreign keys.
# The set is self-contained — nothing kept references anything dropped — so the
# cascade cannot reach a surviving table.
class DropTier1KnowledgeEntities < ActiveRecord::Migration[8.1]
  TABLES = %i[
    contract_detail_contract_types
    contract_details
    contract_organization_detail_contract_organization_types
    contract_organization_details
    contract_organization_types
    contract_organizations
    contract_part_detail_contract_part_types
    contract_part_details
    contract_part_types
    contract_parts
    contract_people
    contract_person_detail_contract_person_types
    contract_person_details
    contract_person_types
    contract_technologies
    contract_technology_detail_contract_technology_types
    contract_technology_details
    contract_technology_types
    contract_types
    contracts
    facilities
    facility_detail_facility_types
    facility_details
    facility_types
    org_org_typings
    organization_detail_organization_types
    organization_details
    organization_organization_details
    organization_organization_types
    organization_organizations
    organization_research_runs
    organization_technologies
    organization_technology_detail_organization_technology_types
    organization_technology_details
    organization_technology_types
    organization_types
    organizations
    part_detail_parameters
    part_detail_part_types
    part_details
    part_organization_detail_part_organization_types
    part_organization_details
    part_organization_types
    part_organizations
    part_part_detail_part_part_types
    part_part_details
    part_part_types
    part_parts
    part_technologies
    part_technology_detail_part_technology_types
    part_technology_details
    part_technology_types
    part_type_parameters
    part_types
    parts
    people
    person_detail_person_types
    person_details
    person_organization_detail_person_organization_types
    person_organization_details
    person_organization_types
    person_organizations
    person_people
    person_person_detail_person_person_types
    person_person_details
    person_person_types
    person_science_detail_person_science_types
    person_science_details
    person_science_types
    person_sciences
    person_types
    science_detail_science_types
    science_details
    science_technologies
    science_technology_detail_science_technology_types
    science_technology_details
    science_technology_types
    science_types
    sciences
    technologies
    technology_detail_technology_types
    technology_details
    technology_types
  ].freeze

  def up
    TABLES.each { |table| drop_table(table, force: :cascade, if_exists: true) }
  end

  # Deliberately irreversible. Reversing this would mean recreating 83 tables and
  # their entire column and index structure inline; that structure lives in the
  # git history, which is the right place to recover it from.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
