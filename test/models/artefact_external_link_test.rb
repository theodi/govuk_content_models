require "test_helper"

class ArtefactExternalLinkTest < ActiveSupport::TestCase
  context "validating a link" do
    should "not be valid without a title or URL" do
      refute ArtefactExternalLink.new.valid?
    end

    should "not be valid with URL missing" do
      refute ArtefactExternalLink.new(:title => "Foo").valid?
    end

    should "not be valid with title missing" do
      refute ArtefactExternalLink.new(:url => "http://bar.com").valid?
    end

    should "be valid with both fields supplied" do
      link = ArtefactExternalLink.new(:title => "Foo", :url => "http://bar.com")
      assert link.valid?
    end
  end
end
