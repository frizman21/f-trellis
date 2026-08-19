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
  #
  # `max_retries` is optional and applies to any model, not only a custom one:
  # RubyLLM retries a dropped connection three times by default, and a caller
  # that knows those retries are wasted needs to be able to say so wherever the
  # model is served from. A model with no endpoint and no override still carries
  # no context at all, so nothing changes for a caller that does not ask.
  def self.for_model(model, max_retries: nil)
    chat = new(model: model)
    endpoint = model.model_endpoint

    if endpoint
      chat.context = endpoint.to_context(max_retries: max_retries)
      chat.assume_model_exists = true
    elsif !max_retries.nil?
      chat.context = RubyLLM.context { |config| config.max_retries = max_retries }
    end

    chat.save!
    chat
  end
end
