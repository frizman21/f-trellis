class PersonScienceDetailsController < ApplicationController
  def show
    @detail = PersonScienceDetail.find(params[:id])
    @edge   = @detail.person_science
    @person  = @edge.person
    @science = @edge.science
    @is_current = @edge.current_detail_id == @detail.id
  end
end
