class ChatsController < ApplicationController
  def index
    # Messages are preloaded because the cost of a chat is computed from them:
    # without this the index is a query per row and another per row for tokens.
    @chats = Chat.includes(:model, :messages).order(created_at: :desc)
                 .page(params[:page]).per(25)
    @costs = @chats.to_h { |chat| [ chat.id, ChatCost.new(chat) ] }
  end

  def show
    @chat = Chat.includes(messages: [ :model, :parent_tool_call, :tool_calls ]).find(params[:id])
    @messages = @chat.messages.order(:created_at)
    @cost = ChatCost.new(@chat)
  end
end
