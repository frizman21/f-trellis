module OntologyHelper
  # Renders a type's name with its attributes attached as a hover popover, so
  # "what does this type carry?" is answerable without leaving the page.
  #
  # Takes the type rather than a prepared list: an entity type and a
  # relationship type both answer #declared_attributes, and asking each caller
  # to assemble the same markup is how two of them end up disagreeing.
  def type_with_attributes(type, url, css_class: nil)
    link_to type.name, url,
            class: css_class,
            data: {
              controller: "type-popover",
              bs_title: type.name,
              bs_content: type_attribute_summary(type)
            }
  end

  # The popover body. Plain text rather than markup: it is set as an attribute
  # value and read back by Bootstrap, and text cannot carry an injection.
  def type_attribute_summary(type)
    attributes = type.declared_attributes
    return "No attributes defined." if attributes.empty?

    attributes.map { |attribute| "#{attribute.name} (#{attribute.value_type})" }.join("\n")
  end
end
