# == Schema Information
#
# Table name: answers
#
#  id              :integer          not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  answerable_id   :integer          not null
#  answerable_type :string           not null
#  name            :string           not null
#  value           :text
#  value_type      :integer
#
# Indexes
#
#  index_answers_on_answerable_type_and_answerable_id  (answerable_type,answerable_id)
#

class Answer < ActiveRecord::Base
  belongs_to :answerable, polymorphic: true

  validates :name, presence: true
  validates :value, uri: true, if: -> (s) { s.value_type == 'url' }
  validates :value, email: true, if: -> (s) { s.value_type == 'email' }

  enum value_type: {
    string: 0,
    password: 1,
    integer: 2,
    boolean: 3,
    array: 4,
    json: 5,
    date: 6,
    datetime: 7,
    fingerprint: 8,
    certificate: 9,
    text: 10,
    url: 11,
    email: 12
  }

  before_save :convert_value

  def value
    v = self[:value]
    v.nil? ? nil : YAML.load(v)
  end

  def value=(v)
    @uncast_value = v
    value_will_change!
  end

  alias_method :value_before_type_cast, :value

  private

  def parse_string_value(val)
    begin
      v = Jellyfish::Cast::String.cast(val, value_type)
      self[:value] = v.to_yaml
    rescue Jellyfish::Cast::FailedCastException => e
      invalid_value_error e.to_s
      return false
    rescue Jellyfish::Cast::UnhandledCastException
      raise StandardError, sprintf("parsing settings type '%s' from string is not defined", value_type)
    end
    true
  end

  # Convert/Cast the value to the proper type
  def convert_value
    # Do nothing if value has not changed
    return true unless value_changed?
    # Cast the value and return success
    return parse_string_value(@uncast_value) if @uncast_value.is_a? String
    # Convert the value to yaml otherwise
    v = @uncast_value.to_yaml unless @uncast_value.nil?
    self[:value] = v
  end

  def invalid_value_error(error)
    errors.add :value, sprintf('is invalid: %s', error)
  end

end
