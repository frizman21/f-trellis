class ContractPeopleController < ApplicationController
  def show
    @contract_person = ContractPerson.find(params[:id])
    @contract = @contract_person.contract
    @person = @contract_person.person
    @current = @contract_person.current_detail
    @details = @contract_person.contract_person_details
                 .includes(:contract_person_types, source_processing_report: :source)
                 .order(as_of: :desc, created_at: :desc)
  end
end
