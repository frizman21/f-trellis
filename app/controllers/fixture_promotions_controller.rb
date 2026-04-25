class FixturePromotionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :update
  skip_before_action :allow_browser, raise: false

  RESOURCES = {
    "sources" => Source,
    "skills"  => Skill
  }.freeze

  # GET /fixture_promotions.json
  def index
    payload = {
      sources: Source.promotable_pending.order(:id).map { |s| serialize_source(s) },
      skills:  Skill.promotable_pending.order(:id).map  { |s| serialize_skill(s) }
    }
    render json: payload
  end

  # PATCH /fixture_promotions/:resource/:id
  def update
    klass = RESOURCES[params[:resource]]
    return render json: { error: "unknown resource" }, status: :not_found if klass.nil?

    record = klass.find(params[:id])
    record.update!(is_fixtured: true)
    render json: { id: record.id, resource: params[:resource], is_fixtured: record.is_fixtured }
  end

  private

  def serialize_source(source)
    {
      id: source.id,
      url: source.url,
      description: source.description,
      status: source.status,
      is_promotable: source.is_promotable,
      is_fixtured: source.is_fixtured,
      created_at: source.created_at
    }
  end

  def serialize_skill(skill)
    revisions = skill.skill_revisions.order(:sequence).map do |r|
      { id: r.id, sequence: r.sequence, content: r.content }
    end

    {
      id: skill.id,
      name: skill.name,
      purpose: skill.purpose,
      is_active: skill.is_active,
      is_promotable: skill.is_promotable,
      is_fixtured: skill.is_fixtured,
      preferred_model_id: skill.preferred_model_id,
      revisions: revisions,
      created_at: skill.created_at
    }
  end
end
