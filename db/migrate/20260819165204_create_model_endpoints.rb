# A model served by something other than the providers RubyLLM discovers.
#
# The token is referenced, never stored: the column holds the name of an
# environment variable, so a live PAT is not in the database, in a backup, or on
# the edit form. The environment already holds OPENAI_API_KEY and
# ANTHROPIC_API_KEY; this is the same place.
class CreateModelEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :model_endpoints do |t|
      t.string :name, null: false
      t.string :base_url, null: false
      # Nullable: an endpoint on a trusted network may want no auth header.
      t.string :api_key_env_var
      t.timestamps
    end

    add_index :model_endpoints, :name, unique: true

    # Nullable, because every model that came from a provider refresh has none.
    # A custom model is an ordinary models row in every other respect, so
    # nothing downstream learns a second way to name a model.
    add_reference :models, :model_endpoint, null: true, foreign_key: true
  end
end
