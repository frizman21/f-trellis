# A run's proposals as a set: how many distinct ones there are, a digest that
# answers "identical to the baseline?" in one comparison, and the three-way split
# against another run.
#
# Order-independent throughout. Two models that find the same organizations in a
# different order contributed the same thing, and a comparison that said
# otherwise would be measuring the reading order rather than the contribution.
class ProposalSet
  def self.digest(proposals) = new(proposals).digest

  def initialize(proposals)
    @proposals = Array(proposals)
  end

  # The proposals with each record's keys sorted, the list sorted and deduped.
  # Records arrive normalised from ProposalRecorder; this is what makes the
  # *collection* canonical rather than each record.
  def distinct
    @distinct ||= @proposals.filter_map { |record| canonical(record) }.uniq.sort_by(&:to_json)
  end

  def size = distinct.size
  def empty? = distinct.empty?

  # SHA over the canonical form. An empty set still digests, so "this run
  # proposed nothing" compares equal to another run that proposed nothing rather
  # than reading as "not run".
  def digest
    @digest ||= Digest::SHA256.hexdigest(distinct.to_json)
  end

  def ==(other) = other.is_a?(ProposalSet) && digest == other.digest

  # Proposals this set and `other` both made.
  def shared_with(other) = distinct & other.distinct

  # Proposals this set made and `other` did not.
  def added_over(other) = distinct - other.distinct

  # Proposals `other` made and this set did not.
  def missing_from(other) = other.distinct - distinct

  private

  def canonical(record)
    return nil unless record.is_a?(Hash)

    record.to_h { |key, value| [ key.to_s, canonical_value(value) ] }.sort.to_h
  end

  def canonical_value(value)
    case value
    when Hash  then value.to_h { |k, v| [ k.to_s, canonical_value(v) ] }.sort.to_h
    when Array then value.map { |v| canonical_value(v) }.sort_by(&:to_s)
    when String then value.strip.downcase
    else value
    end
  end
end
