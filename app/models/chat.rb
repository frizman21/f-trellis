class Chat < ApplicationRecord
  acts_as_chat

  # The one way this application starts a chat against a model.
  #
  # A model served by a custom endpoint needs two things a registered one does
  # not: the endpoint's per-call config, and permission to name a model id that
  # is in no provider's registry. Both are attached here rather than at the four
  # call sites, because a fifth caller that forgot them would not fail loudly —
  # it would quietly send the request to OpenAI under a model id OpenAI has
  # never heard of.
  def self.for_model(model)
    chat = new(model: model)

    if model.model_endpoint
      chat.context = model.model_endpoint.to_context
      chat.assume_model_exists = true
    end

    chat.save!
    chat
  end
end
