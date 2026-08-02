class AddProposalsToSkillEvaluationResults < ActiveRecord::Migration[8.0]
  def change
    # What the run would have written into the knowledge graph, normalised.
    # Mirrors the `facts` jsonb on source_processing_reports.
    add_column :skill_evaluation_results, :proposals, :jsonb, default: [], null: false

    # SHA over the canonical form of `proposals` — keys sorted, values downcased
    # and stripped, the list sorted and deduped. Order-independent, so "this run
    # proposed exactly what the baseline proposed" is one equality check rather
    # than a diff. Indexed because that comparison is made per (page, model)
    # cell across a whole evaluation.
    add_column :skill_evaluation_results, :proposal_digest, :string
    add_index  :skill_evaluation_results, :proposal_digest
  end
end
