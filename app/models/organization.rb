class Organization < ApplicationRecord
  has_many :organization_details, dependent: :destroy
  has_many :person_organizations, dependent: :destroy
  has_many :people, through: :person_organizations

  has_many :organization_organizations_as_a,
           class_name: "OrganizationOrganization",
           foreign_key: :organization_a_id,
           dependent: :destroy,
           inverse_of: :organization_a
  has_many :organization_organizations_as_b,
           class_name: "OrganizationOrganization",
           foreign_key: :organization_b_id,
           dependent: :destroy,
           inverse_of: :organization_b

  belongs_to :current_detail, class_name: "OrganizationDetail", optional: true

  def organization_organizations
    OrganizationOrganization.where(
      "organization_a_id = :id OR organization_b_id = :id",
      id: id
    )
  end
end
