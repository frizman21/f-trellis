namespace :llm do
  namespace :models do
    desc "Refresh the model registry from the live provider APIs (OpenAI, Anthropic, ...) " \
         "plus models.dev metadata. Upserts into the models table; nothing is deleted."
    task refresh: :environment do
      before = Model.count
      puts "[llm:models:refresh] #{before} models in registry, fetching from providers..."

      RefreshModelsJob.perform_now

      current = Model.current.count
      puts "[llm:models:refresh] #{Model.count} models in registry " \
           "(#{Model.count - before} new, #{current} currently offered, #{Model.count - current} retired)"
    end
  end
end
