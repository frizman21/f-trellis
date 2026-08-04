class Skill < ApplicationRecord
  has_many :skill_revisions, dependent: :destroy
  has_many :skill_evaluations, dependent: :destroy
  belongs_to :preferred_model, class_name: "Model", optional: true

  # `applicability` states which pages this skill is worth spending a call on.
  # It is read by the triage step, so an active skill without one cannot be
  # routed — hence the validation. A draft skill can be saved without it.
  validates :applicability, presence: true, if: :is_active?

  # `url_patterns` claim pages outright. Where `applicability` is a statement for
  # the model to judge, a pattern is a fact about the URL: a LinkedIn profile is
  # a LinkedIn profile, and no call is needed to establish that. When one matches
  # a source's URL, that skill runs and the others do not — see SkillTriage.
  #
  # Stored as Ruby regex source strings, matched unanchored and case
  # insensitively against the whole URL, e.g. `linkedin\.com/in/`.
  validate :url_patterns_must_compile

  scope :promotable_pending, -> { where(is_promotable: true, is_fixtured: false) }

  # Skills triage can actually route: active, with a statement to route on, and
  # with a revision to run.
  #
  # Ordered by id so the result is stable. Triage does not rank — it returns
  # every skill that applies — but the order still surfaces: it is the order of
  # `Result#recommended`, and of the names in the "claim(s) ... by URL pattern"
  # log line. Without this, Postgres is free to vary it between runs.
  # Ordering by id rather than name keeps it independent of DB collation.
  scope :triageable, lambda {
    active_with_applicability = where(is_active: true)
                                 .where.not(applicability: nil)
                                 .where.not(applicability: "")
    active_with_applicability.where(id: SkillRevision.select(:skill_id)).order(:id)
  }

  # The revision a run would use. Ordered by `sequence`, not `created_at`: the
  # unique index is on (skill_id, sequence), and the two can disagree.
  def current_revision
    skill_revisions.order(:sequence).last
  end

  # Whether the proposed wording and model differ from what the current revision
  # already pins. A skill with no revisions reports true, so the first one is
  # always minted.
  #
  # This is what makes a revision mean something: without it every save minted
  # one, so the revision list recorded visits to the edit form rather than
  # changes to the skill.
  def revision_changed?(content:, model:)
    revision = current_revision
    return true if revision.nil?

    revision.content.to_s != content.to_s || revision.model_id != model&.id
  end

  # One pattern per line, which is how the form edits them.
  def url_patterns_text
    Array(url_patterns).join("\n")
  end

  def url_patterns_text=(value)
    self.url_patterns = value.to_s.split(/\r?\n/).map(&:strip).reject(&:blank?)
  end

  # The first stored pattern matching `url`, or nil. A pattern that does not
  # compile is skipped rather than raised — validation keeps those out, but a
  # row written around it must not take routing down for the whole page.
  def url_pattern_matching(url)
    return nil if url.blank?

    Array(url_patterns).find { |pattern| compiled_pattern(pattern)&.match?(url.to_s) }
  end

  def claims_url?(url)
    url_pattern_matching(url).present?
  end

  private

  def url_patterns_must_compile
    Array(url_patterns).each do |pattern|
      next if compiled_pattern(pattern)

      errors.add(:url_patterns, "contains an invalid regular expression: #{pattern}")
    end
  end

  def compiled_pattern(pattern)
    Regexp.new(pattern.to_s, Regexp::IGNORECASE)
  rescue RegexpError
    nil
  end
end
