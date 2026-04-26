class PersonPeopleController < ApplicationController
  def show
    @person_person = PersonPerson.find(params[:id])
    @person_a = @person_person.person_a
    @person_b = @person_person.person_b
    @current  = @person_person.current_detail
    @details  = @person_person.person_person_details
                  .includes(:person_person_types, source_processing_report: :source)
                  .order(as_of: :desc, created_at: :desc)
  end
end
