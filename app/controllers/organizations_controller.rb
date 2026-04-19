class OrganizationsController < ApplicationController
  PER_PAGE = 25

  def index
    @query = params[:q].to_s.strip

    if @query.present?
      @match_reasons = compute_match_reasons(@query)
      scope = Organization.where(id: @match_reasons.keys).distinct
    else
      @match_reasons = {}
      scope = Organization.all
    end

    @organizations = scope.order(:id).page(params[:page]).per(PER_PAGE)
  end

  def show
    @organization = Organization.find(params[:id])
  end

  private

  def compute_match_reasons(query)
    pattern = "%#{query}%"
    matching_details = OrganizationDetail.where(
      "name ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(organization_details.additional_attributes) e WHERE e.value ILIKE :q)",
      q: pattern
    )

    reasons = Hash.new { |h, k| h[k] = [] }
    needle = query.downcase

    matching_details.find_each do |d|
      reasons[d.organization_id] << "Name: #{d.name}" if d.name.to_s.downcase.include?(needle)

      d.additional_attributes.each do |key, value|
        reasons[d.organization_id] << "#{key.humanize}: #{value}" if value.to_s.downcase.include?(needle)
      end
    end

    reasons.transform_values(&:uniq)
  end
end
