class PersonPeopleController < ApplicationController
  def show
    @person_person = PersonPerson.find(params[:id])
    @person_a = @person_person.person_a
    @person_b = @person_person.person_b
    @current  = @person_person.current_detail
    @prior    = @person_person.person_person_details
                  .where.not(id: @current&.id)
                  .order(as_of: :desc)
  end
end
