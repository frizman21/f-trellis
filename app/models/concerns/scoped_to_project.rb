# For the ontology tables whose project is also reachable through a parent.
#
# Every ontology table carries project_id, including the three where it is
# derivable. A stored copy of a derivable fact can disagree with the fact, so
# including this pins the copy to the parent: it is filled in from the parent
# when blank, and rejected when it contradicts it. The column stays convenient
# to query without becoming a second source of truth.
module ScopedToProject
  extend ActiveSupport::Concern

  class_methods do
    # `parent` names the association the project must agree with.
    def scoped_to_project_through(parent)
      belongs_to :project

      before_validation { self.project_id ||= public_send(parent)&.project_id }

      validate do
        owner = public_send(parent)
        next if owner.nil? || project_id.nil?
        next if project_id == owner.project_id

        errors.add(:project, "must be the same project as the #{parent.to_s.humanize.downcase}")
      end
    end
  end
end
