class OrganizationOrganization < ApplicationRecord
  belongs_to :organization_a, class_name: "Organization"
  belongs_to :organization_b, class_name: "Organization"
  belongs_to :current_detail, class_name: "OrganizationOrganizationDetail", optional: true
  has_many :organization_organization_details, dependent: :destroy

  def other_organization(organization)
    organization_a_id == organization.id ? organization_b : organization_a
  end
end
