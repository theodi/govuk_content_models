require "edition"
require "expectant"

class PlaceEdition < Edition
  include Expectant

  field :introduction,      type: String
  field :more_information,  type: String
  field :place_type,        type: String

  GOVSPEAK_FIELDS = Edition::GOVSPEAK_FIELDS + [:introduction, :more_information]

  @fields_to_clone = [:introduction, :more_information, :place_type,
                      :expectation_ids]

  def whole_body
    self.introduction
  end

end
