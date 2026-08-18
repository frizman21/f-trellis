# The storage half of a typed attribute: four typed columns, exactly one of them
# live, chosen by the declared value_type of the attribute this value is for.
#
# Shared by EntityAttributeValue and RelationshipTypeValue. Including it requires
# a `typed_attribute` method naming the attribute record that declares the type.
module TypedValue
  extend ActiveSupport::Concern

  included do
    validate :value_is_castable
  end

  def value_type = typed_attribute&.value_type
  def value_column = typed_attribute&.value_column

  def value
    return nil if typed_attribute.nil?

    public_send(value_column)
  end

  # Writing clears the other three columns, so an attribute whose type is changed
  # after the fact cannot leave a stale value behind in a column nothing reads.
  def value=(raw)
    return if typed_attribute.nil?

    TypedAttribute::VALUE_COLUMNS.each_value { |column| public_send(:"#{column}=", nil) }
    @uncastable = false
    return if raw.blank?

    cast = cast_value(raw)
    if cast.nil?
      @uncastable = raw
    else
      public_send(:"#{value_column}=", cast)
    end
  end

  # Rendered form of the value, for the attributes table.
  def display_value
    case value
    when nil then ""
    when Time, DateTime, ActiveSupport::TimeWithZone then value.strftime("%Y-%m-%d %H:%M")
    else value.to_s
    end
  end

  private

  # nil means "not castable" — distinct from a blank input, which is handled
  # before this is reached and simply records nothing.
  def cast_value(raw)
    case value_type
    when "int"      then Integer(raw.to_s, exception: false)
    when "float"    then Float(raw.to_s, exception: false)
    when "string"   then raw.to_s
    when "datetime" then parse_time(raw)
    end
  end

  def parse_time(raw)
    return raw if raw.respond_to?(:strftime)

    Time.zone.parse(raw.to_s)
  rescue ArgumentError
    nil
  end

  def value_is_castable
    return if @uncastable.blank?

    errors.add(:value, "#{@uncastable.inspect} is not a valid #{value_type}")
  end
end
