# Who has an account, and what they are allowed to do.
#
# No authorisation of its own: there are no roles in this application beyond the
# read-only flag, and every signed-in user can already see every other page.
# Restricting this one would mean inventing a permissions model in passing.
class UsersController < ApplicationController
  def index
    @users = User.order(:email)
  end
end
