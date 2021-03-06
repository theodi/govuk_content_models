require "test_helper"
require "fact_check_address"

class FactCheckAddressTest < ActiveSupport::TestCase

  setup do
    dummy_plek = mock do
      stubs(:find).with("publisher").returns("publisher.wibble.alphagov.co.uk")
    end
    Plek.stubs(:current).returns(dummy_plek)
  end

  test "can tell if an address is valid" do
    service = FactCheckAddress.new
    address = service.for_edition(Edition.new)
    assert service.valid_address?(address), "Address should be valid but isn't"
  end

  test "can tell if an address is invalid" do
    service = FactCheckAddress.new
    address = "factcheck+notwibble-abde@alphagov.co.uk"
    refute service.valid_address?(address), "Address should be invalid but isn't"
  end

  test "can extract edition ID from an address" do
    service = FactCheckAddress.new
    address = "factcheck+wibble-abde@alphagov.co.uk"
    assert_equal "abde", service.edition_id_from_address(address)
  end

  test "can generate an address from an edition" do
    service = FactCheckAddress.new
    e = Edition.new
    assert_match /#{e.id}/, service.for_edition(e)
  end
end
