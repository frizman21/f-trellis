class AddDeprecatedAndDisabledToModels < ActiveRecord::Migration[8.0]
  def change
    # Two reasons a model is out of circulation, kept apart because they are
    # undone by different people: `is_deprecated` is what the provider told us
    # by refusing the call, `is_disabled` is a choice we made.
    #
    # RubyLLM's `save_to_database` writes only the registry attributes it knows
    # about, so both flags survive every RefreshModelsJob untouched.
    add_column :models, :is_deprecated, :boolean, null: false, default: false
    add_column :models, :is_disabled, :boolean, null: false, default: false

    add_index :models, [ :is_deprecated, :is_disabled ]
  end
end
