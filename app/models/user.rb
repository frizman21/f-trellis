class User < ApplicationRecord
  # `read_only` accounts may read anything and change nothing — enforced in
  # ApplicationController, which refuses any request that is not a GET or HEAD.
  # Intended for diagnosis: reading production to answer "why did this run
  # behave that way" without being one stray POST from spending money on a
  # model call or editing the knowledge base.

  # Admin-invite only — no public sign-up. New users are created via the
  # rails console (see README).
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable
end
