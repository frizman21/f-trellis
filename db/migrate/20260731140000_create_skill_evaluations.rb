class CreateSkillEvaluations < ActiveRecord::Migration[8.1]
  def change
    create_table :skill_evaluations do |t|
      t.string  :name, null: false
      t.text    :description
      t.references :skill, null: false, foreign_key: true
      # The pages to run against are a learning set, not a list of this
      # evaluation's own — the same set is what makes two evaluations
      # comparable.
      t.references :learning_set, null: false, foreign_key: true
      # The model the others are judged against. Scoring is not implemented yet;
      # the baseline is recorded now so it can be.
      t.references :base_model, null: false, foreign_key: { to_table: :models }
      t.timestamps
    end

    create_table :skill_evaluation_models do |t|
      t.references :skill_evaluation, null: false, foreign_key: { on_delete: :cascade }
      t.references :model, null: false, foreign_key: true
      t.timestamps
    end

    add_index :skill_evaluation_models, [ :skill_evaluation_id, :model_id ],
              unique: true, name: "index_skill_evaluation_models_on_pair"

    create_table :skill_evaluation_results do |t|
      t.references :skill_evaluation, null: false, foreign_key: { on_delete: :cascade }
      t.references :source, null: false, foreign_key: true
      t.references :model, null: false, foreign_key: true
      # Which wording actually produced this response — the reason a result stays
      # explainable after the skill is edited.
      t.references :skill_revision, null: false, foreign_key: true
      t.references :chat, null: true, foreign_key: true
      t.string   :status, null: false, default: "pending"
      # Nullable on purpose: how a response is scored is not decided yet, and a
      # made-up number would be worse than none.
      t.decimal  :score, precision: 6, scale: 3
      t.text     :response
      t.text     :error
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :skill_evaluation_results,
              [ :skill_evaluation_id, :source_id, :model_id, :skill_revision_id ],
              unique: true, name: "index_skill_evaluation_results_on_run"
  end
end
