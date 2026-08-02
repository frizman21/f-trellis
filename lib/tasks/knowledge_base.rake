# Knowledge base maintenance tasks.
#
# `kb:clean` empties the tier 1 knowledge base — the entities themselves, their
# versioned detail records, and the relationships between them. It deliberately
# leaves everything that is *not* knowledge content:
#
#   * type taxonomies (PersonType, OrganizationType, …) — user-editable
#     reference data with their own CRUD controllers, not seeded content
#   * skills and skill revisions, evaluations
#   * sources, source data, source links, processing reports, learning sets
#   * users, models, chats
#
# The usual reason to run it is a deployment that was seeded with demo data —
# see the SEED_KNOWLEDGE_BASE guard in db/seeds.rb, which stops that happening
# in the first place on anything but development and test.

namespace :kb do
  # Ordered parent-first for reporting. Destruction runs in the reverse
  # direction: relationships before the entities they join.
  ENTITY_MODELS = %w[Person Organization Part Facility].freeze

  RELATIONSHIP_MODELS = %w[
    PersonPerson PersonOrganization OrganizationOrganization
    PartPart PartOrganization
  ].freeze

  DETAIL_MODELS = %w[
    PersonDetail OrganizationDetail PartDetail FacilityDetail
    PersonPersonDetail PersonOrganizationDetail OrganizationOrganizationDetail
    PartPartDetail PartOrganizationDetail
  ].freeze

  PRESERVED_MODELS = %w[
    PersonType OrganizationType PartType FacilityType
    Skill Source SourceProcessingReport User Model
  ].freeze

  def counts_for(names)
    names.to_h { |n| [ n, n.constantize.count ] }
  end

  def print_counts(title, counts)
    puts "  #{title}"
    width = counts.keys.map(&:length).max.to_i
    counts.each { |name, n| puts "    #{name.ljust(width)}  #{n}" }
  end

  desc "Delete all tier 1 knowledge content. Keeps type taxonomies, skills, sources, users and models. DRY_RUN=1 to preview."
  task clean: :environment do
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV["DRY_RUN"])
    targets = RELATIONSHIP_MODELS + ENTITY_MODELS + DETAIL_MODELS

    before = counts_for(targets)

    puts "Knowledge base cleanup (#{Rails.env})#{' — DRY RUN' if dry_run}"
    puts
    print_counts("Before:", before)
    puts

    if before.values.sum.zero?
      puts "  Nothing to delete."
      next
    end

    if dry_run
      puts "  DRY_RUN set — nothing deleted."
      next
    end

    ActiveRecord::Base.transaction do
      # Entities and relationship rows both carry a current_detail_id FK
      # pointing *into* their detail table, so the detail rows cannot be
      # deleted while those pointers are still set. Clear them first, then let
      # `dependent: :destroy` cascade from the parents down through the
      # details to their type-join rows.
      (RELATIONSHIP_MODELS + ENTITY_MODELS).each do |name|
        name.constantize.unscoped.update_all(current_detail_id: nil)
      end

      RELATIONSHIP_MODELS.each { |name| name.constantize.destroy_all }
      ENTITY_MODELS.each       { |name| name.constantize.destroy_all }
    end

    print_counts("After:", counts_for(targets))
    puts
    print_counts("Preserved:", counts_for(PRESERVED_MODELS))
  end
end
