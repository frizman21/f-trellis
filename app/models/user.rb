class User < ApplicationRecord
  # Admin-invite only — no public sign-up. New users are created via the
  # rails console (see README).
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable
end
