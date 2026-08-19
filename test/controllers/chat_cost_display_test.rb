require "test_helper"

class ChatCostDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @model = Model.create!(provider: "anthropic", model_id: "priced", name: "P",
                           last_seen_at: Time.current,
                           pricing: { "text_tokens" => { "standard" => {
                             "input_per_million" => 10, "output_per_million" => 20 } } })
    @chat = Chat.create!(model: @model)
    @chat.messages.create!(role: "system", content: "a" * 4000)
    @chat.messages.create!(role: "assistant", content: "reply", output_tokens: 2000,
                           input_tokens: 3, cached_tokens: 500)
  end

  test "the chat page shows the parts and the total" do
    get chat_path(@chat)

    assert_response :success
    assert_select "h2", text: "Cost"
    body = response.body

    assert_match(/2,000/, body)      # output tokens
    # 500 estimated input tokens billable (1000 - 500 cached) at $10/Mtok = $0.005,
    # 500 cached at the input rate = $0.005, 2000 output at $20/Mtok = $0.04.
    assert_match(/\$0\.0500/, body)
  end

  # The word has to be on the screen: the input side is derived, not recorded.
  test "the chat page says the figure is an estimate and why" do
    get chat_path(@chat)

    assert_match(/estimate/i, response.body)
    assert_match(/estimated from content/i, response.body)
    assert_match(/recorded input token count is wrong/i, response.body)
  end

  test "cached tokens are flagged as priced at the full input rate" do
    get chat_path(@chat)

    assert_match(/no cached rate recorded/i, response.body)
  end

  test "a chat with an unpriced model says so rather than showing zero" do
    unpriced = Model.create!(provider: "anthropic", model_id: "unpriced", name: "U",
                             last_seen_at: Time.current)
    chat = Chat.create!(model: unpriced)

    get chat_path(chat)

    assert_response :success
    assert_match(/No pricing recorded/i, response.body)
  end

  # --- the index -------------------------------------------------------------

  test "the index shows a cost per row" do
    get chats_path

    assert_response :success
    assert_select "th", text: "Est. cost"
    assert_match(/\$0\.0500/, response.body)
  end

  # A total that does not match the rows above it is the bug this most likely has.
  test "the page total equals the sum of the rows shown" do
    second = Chat.create!(model: @model)
    second.messages.create!(role: "system", content: "b" * 4000)
    second.messages.create!(role: "assistant", content: "r", output_tokens: 2000)

    get chats_path

    expected = Chat.all.sum { |c| ChatCost.new(c).total.to_f }

    assert_match(/\$#{Regexp.escape(format("%.4f", expected))}/, response.body)
  end

  # Labelled for the page it is on, since the table is paginated.
  test "the total says it is for this page" do
    get chats_path

    assert_match(/chats on this page/i, response.body)
  end

  test "an unpriced chat shows a dash rather than zero" do
    Chat.destroy_all
    unpriced = Model.create!(provider: "anthropic", model_id: "unpriced", name: "U",
                             last_seen_at: Time.current)
    Chat.create!(model: unpriced)

    get chats_path

    assert_select "td", text: "—"
  end
end
