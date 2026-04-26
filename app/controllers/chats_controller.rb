class ChatsController < ApplicationController
  def index
    @chats = Chat.includes(:model).order(created_at: :desc).page(params[:page]).per(25)
  end

  def show
    @chat = Chat.includes(messages: [ :model, :parent_tool_call, :tool_calls ]).find(params[:id])
    @messages = @chat.messages.order(:created_at)
  end
end
