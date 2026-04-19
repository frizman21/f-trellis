class FacilitiesController < ApplicationController
  def index
    @query = params[:q].to_s.strip

    if @query.present?
      @match_reasons = compute_match_reasons(@query)
      @facilities = Facility.where(id: @match_reasons.keys).distinct
    else
      @match_reasons = {}
      @facilities = Facility.all
    end
  end

  def show
    @facility = Facility.find(params[:id])
  end

  private

  def compute_match_reasons(query)
    pattern = "%#{query}%"
    matching_details = FacilityDetail.where(
      "address ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(facility_details.additional_attributes) e WHERE e.value ILIKE :q)",
      q: pattern
    )

    reasons = Hash.new { |h, k| h[k] = [] }
    needle = query.downcase

    matching_details.find_each do |d|
      reasons[d.facility_id] << "Address: #{d.address}" if d.address.to_s.downcase.include?(needle)

      d.additional_attributes.each do |key, value|
        reasons[d.facility_id] << "#{key.humanize}: #{value}" if value.to_s.downcase.include?(needle)
      end
    end

    reasons.transform_values(&:uniq)
  end
end
