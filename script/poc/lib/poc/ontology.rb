# frozen_string_literal: true

require "json"

module Poc
  # The project's mental model, as exported by bin/export-model and read back by
  # everything downstream that has to judge an extraction.
  #
  # Both validate-json and score-json need to answer "is this a real type?" and
  # "is this a declared attribute of it?", and they must answer identically — a
  # validator that accepts a type the scorer then treats as unknown would report
  # a clean run and a zero score for the same file. One reader, one answer.
  class Ontology
    def self.load(path = Poc.mental_model_file)
      raise Poc::Error, "no mental model at #{path} — run bin/export-model" unless File.exist?(path)

      new(Poc.read_json(path))
    end

    def initialize(data)
      @data = data
      @entity_types = index(data["entity_types"])
      @relationship_types = index(data["relationship_types"])
    end

    attr_reader :data

    def project_name = @data.dig("project", "name")

    # The JSON Schema the model is shown. Carried through so llm-process can
    # optionally constrain decoding with the same schema the prompt describes —
    # if the two ever disagreed, the model would be told one thing and held to
    # another.
    def schema = @data["schema"]

    def entity_type_names = @entity_types.values.map { |t| t["name"] }
    def relationship_type_names = @relationship_types.values.map { |t| t["name"] }

    # Exact match, for validation. A type whose name differs only in case is not
    # the declared type: the prompt gives an enum, and a model that ignores it
    # has done something worth seeing rather than something to quietly absorb.
    def entity_type?(name) = entity_type_names.include?(name.to_s)
    def relationship_type?(name) = relationship_type_names.include?(name.to_s)

    # Case- and whitespace-insensitive, for scoring. Once a run is being scored
    # the question is whether the model found the same thing, and "organization"
    # against "Organization" is the same thing found.
    def entity_type(name) = @entity_types[key(name)]
    def relationship_type(name) = @relationship_types[key(name)]

    def entity_attribute_names(type_name)
      entity_type(type_name)&.dig("attributes")&.map { |a| a["name"] } || []
    end

    def relationship_attribute_names(type_name)
      relationship_type(type_name)&.dig("attributes")&.map { |a| a["name"] } || []
    end

    def entity_attribute(type_name, attribute_name)
      find_attribute(entity_type(type_name), attribute_name)
    end

    def relationship_attribute(type_name, attribute_name)
      find_attribute(relationship_type(type_name), attribute_name)
    end

    # Which entity types a relationship type is allowed to join, in order. The
    # database enforces this and the prompt states it, so an extraction that
    # breaks it cannot be applied — which makes it a validation error rather
    # than a scoring penalty.
    def relationship_ends(type_name)
      type = relationship_type(type_name)
      return nil if type.nil?

      [ type["from"], type["to"] ]
    end

    private

    def index(types)
      Array(types).to_h { |type| [ key(type["name"]), type ] }
    end

    def find_attribute(type, attribute_name)
      return nil if type.nil?

      Array(type["attributes"]).find { |a| key(a["name"]) == key(attribute_name) }
    end

    def key(name) = name.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
