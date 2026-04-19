class PeopleController < ApplicationController
  PER_PAGE = 25

  def index
    @query = params[:q].to_s.strip

    if @query.present?
      @match_reasons = compute_match_reasons(@query)
      scope = Person.where(id: @match_reasons.keys).distinct
    else
      @match_reasons = {}
      scope = Person.all
    end

    @people = scope.order(:id).page(params[:page]).per(PER_PAGE)
  end

  def show
    @person = Person.find(params[:id])
  end

  private

  def compute_match_reasons(query)
    pattern = "%#{query}%"
    matching_details = PersonDetail.where(
      "first_name ILIKE :q OR last_name ILIKE :q OR EXISTS (SELECT 1 FROM jsonb_each_text(person_details.additional_attributes) e WHERE e.value ILIKE :q)",
      q: pattern
    )

    reasons = Hash.new { |h, k| h[k] = [] }
    needle = query.downcase

    matching_details.find_each do |d|
      reasons[d.person_id] << "First name: #{d.first_name}" if d.first_name.to_s.downcase.include?(needle)
      reasons[d.person_id] << "Last name: #{d.last_name}"   if d.last_name.to_s.downcase.include?(needle)

      d.additional_attributes.each do |key, value|
        reasons[d.person_id] << "#{key.humanize}: #{value}" if value.to_s.downcase.include?(needle)
      end
    end

    reasons.transform_values(&:uniq)
  end
end
