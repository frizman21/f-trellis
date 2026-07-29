class RefreshModelsJob < ApplicationJob
  queue_as :default

  # Pulls the live model list from every configured provider (their /models
  # endpoints) plus models.dev metadata, upserts it into the `models` table, and
  # stamps every model that came back with one shared `last_seen_at`.
  #
  # Nothing is deleted: models a provider has retired simply keep their older
  # timestamp and fall out of `Model.current`.
  def perform
    Model.refresh!
    self.class.stamp_last_seen(RubyLLM.models.all)
  end

  # Stamps one shared timestamp across every model in `model_infos` (anything
  # responding to #provider and #id). Sharing a single timestamp is what lets
  # `Model.current` select exactly the set from the latest refresh.
  def self.stamp_last_seen(model_infos, seen_at: Time.current)
    model_infos.group_by(&:provider).each do |provider, infos|
      Model.where(provider: provider, model_id: infos.map(&:id))
           .update_all(last_seen_at: seen_at)
    end
  end
end
