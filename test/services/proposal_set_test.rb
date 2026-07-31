require "test_helper"

class ProposalSetTest < ActiveSupport::TestCase
  def org(name, **extra)
    { "type" => "organization", "name" => name, "attributes" => {} }.merge(extra.stringify_keys)
  end

  test "two runs proposing the same set in a different order digest the same" do
    one = ProposalSet.new([ org("acme"), org("beta"), org("gamma") ])
    other = ProposalSet.new([ org("gamma"), org("acme"), org("beta") ])

    assert_equal one.digest, other.digest
    assert_equal one, other
  end

  test "a run proposing more digests differently" do
    fewer = ProposalSet.new([ org("acme") ])
    more = ProposalSet.new([ org("acme"), org("beta") ])

    assert_not_equal fewer.digest, more.digest
  end

  test "the same proposal twice counts once" do
    set = ProposalSet.new([ org("acme"), org("acme"), org("beta") ])

    assert_equal 2, set.size
  end

  test "key order within a record does not change the digest" do
    one = ProposalSet.new([ { "type" => "organization", "name" => "acme" } ])
    other = ProposalSet.new([ { "name" => "acme", "type" => "organization" } ])

    assert_equal one.digest, other.digest
  end

  test "casing and surrounding space do not change the digest" do
    one = ProposalSet.new([ { "type" => "organization", "name" => "  Acme Corp " } ])
    other = ProposalSet.new([ { "type" => "organization", "name" => "acme corp" } ])

    assert_equal one.digest, other.digest
  end

  # Two runs that both proposed nothing contributed the same thing. Reading that
  # as "not comparable" would hide the case worth knowing about — a model that
  # silently found nothing on every page.
  test "an empty set still digests, and two empty sets agree" do
    assert_equal ProposalSet.new([]).digest, ProposalSet.new(nil).digest
    assert ProposalSet.new([]).empty?
  end

  test "the three-way split against another set" do
    mine = ProposalSet.new([ org("acme"), org("beta") ])
    base = ProposalSet.new([ org("acme"), org("gamma") ])

    assert_equal [ org("acme") ], mine.shared_with(base)
    assert_equal [ org("beta") ], mine.added_over(base)
    assert_equal [ org("gamma") ], mine.missing_from(base)
  end

  test "a nested attribute bag is canonicalised too" do
    one = ProposalSet.new([ org("acme", attributes: { "sector" => "Defense", "hq" => "VA" }) ])
    other = ProposalSet.new([ org("acme", attributes: { "hq" => "va", "sector" => "defense" }) ])

    assert_equal one.digest, other.digest
  end

  # An organization-to-organization proposal carries the pair as an array; two
  # runs naming the same pair either way round contributed the same edge.
  test "a list value is order-independent" do
    one = ProposalSet.new([ { "type" => "organization_organization", "organizations" => [ "zeta", "alpha" ] } ])
    other = ProposalSet.new([ { "type" => "organization_organization", "organizations" => [ "alpha", "zeta" ] } ])

    assert_equal one.digest, other.digest
  end
end
