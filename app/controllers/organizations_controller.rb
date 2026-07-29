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

  def edit
    @organization = Organization.find(params[:id])
  end

  # Edits the organization's *current* detail in place. Details are normally
  # immutable assertions produced by a SourceProcessingReport; a manual
  # correction has no report to attach a new detail to, so it amends the
  # detail the organization already points at.
  def update
    @organization = Organization.find(params[:id])
    detail = @organization.current_detail

    return redirect_to organization_path(@organization),
                       alert: "Organization has no current detail to edit." if detail.nil?

    if detail.update(organization_detail_params)
      redirect_to organization_path(@organization), notice: "Organization updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def organization_detail_params
    params.require(:organization).permit(:acronym)
  end

  def compute_match_reasons(query)
    pattern = "%#{query}%"
    matching_details = OrganizationDetail.where(
      "name ILIKE :q OR acronym ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(organization_details.additional_attributes) e WHERE e.value ILIKE :q)",
      q: pattern
    )

    reasons = Hash.new { |h, k| h[k] = [] }
    needle = query.downcase

    matching_details.find_each do |d|
      reasons[d.organization_id] << "Name: #{d.name}" if d.name.to_s.downcase.include?(needle)
      reasons[d.organization_id] << "Acronym: #{d.acronym}" if d.acronym.to_s.downcase.include?(needle) && d.acronym.present?

      d.additional_attributes.each do |key, value|
        reasons[d.organization_id] << "#{key.humanize}: #{value}" if value.to_s.downcase.include?(needle)
      end
    end

    reasons.transform_values(&:uniq)
  end
end
