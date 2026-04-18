[
  { first_name: "Ada",      last_name: "Lovelace",  as_of: Time.zone.parse("1843-10-01"), confidence_tenths: 1000 },
  { first_name: "Alan",     last_name: "Turing",    as_of: Time.zone.parse("1936-01-01"), confidence_tenths: 1000 },
  { first_name: "Grace",    last_name: "Hopper",    as_of: Time.zone.parse("1944-06-01"), confidence_tenths: 1000 },
  { first_name: "Linus",    last_name: "Torvalds",  as_of: Time.zone.parse("1991-08-25"), confidence_tenths: 950 },
  { first_name: "Margaret", last_name: "Hamilton",  as_of: Time.zone.parse("1969-07-20"), confidence_tenths: 900 }
].each do |attrs|
  detail = PersonDetail.find_by(first_name: attrs[:first_name], last_name: attrs[:last_name])
  next if detail

  person = Person.create!
  PersonDetail.create!(attrs.merge(person: person, additional_attributes: {}))
end
