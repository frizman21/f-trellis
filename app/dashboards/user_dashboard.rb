require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  #
  # encrypted_password and reset_password_token are declared here — this hash is
  # the model's field map — but appear in none of the three lists below. The
  # generator put both on the index, the show page and the form, which is wrong
  # three separate ways: a bcrypt digest on a list view is offline cracking
  # material on screen, a live reset token is enough to take an account over,
  # and an editable password field would write whatever was typed straight into
  # the digest column, locking the account out with no error. Passwords are set
  # from the console (see User), so nothing that was ever meant to be possible
  # is lost by leaving them off.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    email: Field::String,
    encrypted_password: Field::String,
    is_admin: Field::Boolean,
    read_only: Field::Boolean,
    remember_created_at: Field::DateTime,
    reset_password_sent_at: Field::DateTime,
    reset_password_token: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    email
    is_admin
    read_only
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    email
    is_admin
    read_only
    remember_created_at
    reset_password_sent_at
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  #
  # The two flags and the address, and nothing to do with credentials.
  FORM_ATTRIBUTES = %i[
    email
    is_admin
    read_only
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(user)
  #   "User ##{user.id}"
  # end
end
