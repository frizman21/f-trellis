# frozen_string_literal: true

require "json"

module Poc
  # One model reply, parsed into the comparable form the scorer needs.
  #
  # The ids in a reply are the model's own — "e1", "org-nasa", whatever it chose
  # — and they mean nothing outside that one reply. Two runs that found exactly
  # the same organizations and exactly the same relationship between them will
  # have numbered them differently, so comparing relationships by their raw
  # from/to ids scores a perfect match as a total miss.
  #
  # Everything here therefore resolves ids to (type, name) before comparing.
  # That is also the identity the database uses, which is what makes a score
  # here a prediction about what would land in the graph.
  #
  # Nothing raises on malformed input. This class exists to read the output of a
  # model that may well have returned nonsense, and "the reply was shaped wrong"
  # is a result to score, not an exception to crash on — validate-json is where
  # shape is judged.
  class Extraction
    def self.load(path)
      return new(nil) unless File.exist?(path)

      new(JSON.parse(File.read(path)))
    rescue JSON::ParserError
      new(nil)
    end

    def initialize(data)
      @data = data.is_a?(Hash) ? data : {}
    end

    attr_reader :data

    def parsed? = !@data.empty?

    def entities = array("entities")
    def relationships = array("relationships")

    # The identity of an entity: its type and what the source calls it. Both
    # normalized, because "  NASA " and "NASA" are the same organization and a
    # scorer that disagreed would be measuring whitespace.
    def entity_key(entity)
      return nil unless entity.is_a?(Hash)

      name = normalize(entity["name"])
      type = normalize(entity["type"])
      return nil if name.empty? || type.empty?

      [ type, name ]
    end

    def entity_keys = entities.filter_map { |e| entity_key(e) }.uniq

    # The model's id => the entity identity it refers to. Duplicated ids keep the
    # first binding, matching the order a reader would resolve them in.
    def id_index
      @id_index ||= entities.each_with_object({}) do |entity, index|
        next unless entity.is_a?(Hash)

        id = entity["id"].to_s
        next if id.empty? || index.key?(id)

        key = entity_key(entity)
        index[id] = key if key
      end
    end

    # (type, from-identity, to-identity). A relationship whose ends do not
    # resolve to declared entities is dropped rather than compared: it cannot
    # match anything in the golden file, and counting it as a near miss would
    # flatter a reply that referenced entities it never listed. validate-json
    # reports it as the error it is.
    def relationship_keys
      relationships.filter_map do |relationship|
        next unless relationship.is_a?(Hash)

        type = normalize(relationship["type"])
        from = id_index[relationship["from"].to_s]
        to = id_index[relationship["to"].to_s]
        next if type.empty? || from.nil? || to.nil?

        [ type, from, to ]
      end.uniq
    end

    # (entity-identity, attribute, value). Attributes are scored separately from
    # the entities carrying them: a run that finds every organization but no
    # detail about any of them, and one that finds half of them completely, are
    # different failures and a single number would hide which one happened.
    def entity_attributes
      entities.flat_map do |entity|
        key = entity_key(entity)
        next [] if key.nil?

        attributes_of(entity).map { |name, value| [ key, name, value ] }
      end.uniq
    end

    def relationship_attributes
      relationships.filter_map do |relationship|
        next unless relationship.is_a?(Hash)

        type = normalize(relationship["type"])
        from = id_index[relationship["from"].to_s]
        to = id_index[relationship["to"].to_s]
        next if type.empty? || from.nil? || to.nil?

        attributes_of(relationship).map { |name, value| [ [ type, from, to ], name, value ] }
      end.flatten(1).uniq
    end

    private

    def array(key)
      value = @data[key]
      value.is_a?(Array) ? value : []
    end

    def attributes_of(record)
      bag = record["attributes"]
      return [] unless bag.is_a?(Hash)

      bag.filter_map do |name, value|
        name = normalize(name)
        value = normalize(value)
        next if name.empty? || value.empty?

        [ name, value ]
      end
    end

    def normalize(value)
      value.to_s.strip.downcase.gsub(/\s+/, " ")
    end
  end
end
