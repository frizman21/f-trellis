class PersonTypesController < ApplicationController
  def index
    @person_types = PersonType.order(:name)
  end
end
