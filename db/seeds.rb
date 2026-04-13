# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

[
  { first_name: "Ada",     last_name: "Lovelace" },
  { first_name: "Alan",    last_name: "Turing" },
  { first_name: "Grace",   last_name: "Hopper" },
  { first_name: "Linus",   last_name: "Torvalds" },
  { first_name: "Margaret", last_name: "Hamilton" }
].each do |attrs|
  Person.find_or_create_by!(attrs)
end
