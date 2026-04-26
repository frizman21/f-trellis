class PersonPersonDetailsController < ApplicationController
  def show
    @detail = PersonPersonDetail.find(params[:id])
    @edge   = @detail.person_person
    @person_a = @edge.person_a
    @person_b = @edge.person_b
    @is_current = @edge.current_detail_id == @detail.id
  end
end
