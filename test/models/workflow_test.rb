require "test_helper"
require "expectation"
require "user"
require "guide_edition"
require "programme_edition"
require "transaction_edition"

class WorkflowTest < ActiveSupport::TestCase
  def template_users
    user = User.create(name: "Bob")
    other_user = User.create(name: "James")
    return user, other_user
  end

  def template_programme
    p = ProgrammeEdition.new(slug:"childcare", title:"Children", panopticon_id: 987353)
    p.start_work
    p.save
    p
  end

  def template_guide
    edition = FactoryGirl.create(:guide_edition, slug: "childcare", title: "One", panopticon_id: 1234574)
    edition.start_work
    edition.save
    edition
  end

  def publisher_and_guide
    user = User.create(name: "Ben")
    other_user = User.create(name: "James")

    guide = user.create_edition(:guide, panopticon_id: 1234574, overview: "My Overview", title: "My Title", slug: "my-title", alternative_title: "My Other Title")
    edition = guide
    user.start_work(edition)
    user.request_review(edition,{comment: "Review this guide please."})
    other_user.approve_review(edition, {comment: "I've reviewed it"})
    user.send_fact_check(edition,{comment: "Review this guide please.", email_addresses: "test@test.com"})
    user.receive_fact_check(edition, {comment: "No changes needed, this is all correct"})
    other_user.approve_fact_check(edition, {comment: "Looks good to me"})
    user.publish(edition, {comment: "PUBLISHED!"})
    return user, guide
  end

  def template_user_and_published_transaction
    user = User.create(name: "Ben")
    other_user = User.create(name: "James")
    expectation = Expectation.create css_class:"card_payment",  text:"Credit card required"

    transaction = user.create_edition(:transaction, title: "My title", slug: "my-title", panopticon_id: 123)
    transaction.expectation_ids = [expectation.id]
    transaction.save

    transaction.start_work
    transaction.save
    user.request_review(transaction, {comment: "Review this guide please."})
    transaction.save
    other_user.approve_review(transaction, {comment: "I've reviewed it"})
    transaction.save
    user.publish(transaction, {comment: "Let's go"})
    transaction.save
    return user, transaction
  end

  test "permits the creation of new editions" do
    user, transaction = template_user_and_published_transaction
    assert transaction.persisted?
    assert transaction.published?

    reloaded_transaction = TransactionEdition.find(transaction.id)
    new_edition = user.new_version(reloaded_transaction)

    assert new_edition.save
  end

  test "a new answer is lined up" do
    g = AnswerEdition.new(slug: "childcare", panopticon_id: "123", title: "My new answer")
    assert g.lined_up?
  end

  test "starting work on an answer removes it from lined up" do
    g = AnswerEdition.new(slug: "childcare", panopticon_id: "123", title: "My new answer")
    g.save!
    user = User.create(name: "Ben")
    user.start_work(g)
    assert_equal false, g.lined_up?
  end

  test "a new guide has lined_up but isn't published" do
    g = FactoryGirl.create(:guide_edition)
    assert g.lined_up?
    refute g.published?
  end

  test "when work started a new guide has draft but isn't published" do
    g = FactoryGirl.create(:guide_edition)
    g.start_work
    assert g.draft?
    refute g.published?
  end

  test "a guide should be marked as having reviewables if requested for review" do
    guide = template_guide
    user = User.create(name:"Ben")
    refute guide.in_review?
    user.request_review(guide, {comment: "Review this guide please."})
    assert guide.in_review?
  end

  test "guide workflow" do
    user = User.create(name: "Ben")
    other_user = User.create(name: "James")

    guide = user.create_edition(:guide, title: "My Title", slug: "my-title", panopticon_id: "12345")
    edition = guide
    user.start_work(edition)
    assert edition.can_request_review?
    user.request_review(edition,{comment: "Review this guide please."})
    refute edition.can_request_review?
    assert edition.can_request_amendments?
    other_user.request_amendments(edition, {comment: "I've reviewed it"})
    refute edition.can_request_amendments?
    user.request_review(edition,{comment: "Review this guide please."})
    assert edition.can_approve_review?
    other_user.approve_review(edition, {comment: "Looks good to me"})
    assert edition.can_publish?
  end

  test "when fact check has been initiated it can be skipped" do
    user = User.create(name: "Ben")
    other_user = User.create(name: "James")

    edition = user.create_whole_edition(:guide, panopticon_id: 1234574, overview: "My Overview", title: "My Title", slug: "my-title", alternative_title: "My Other Title")

    user.start_work(edition)
    user.request_review(edition,{comment: "Review this guide please."})
    other_user.approve_review(edition, {comment: "I've reviewed it"})
    user.send_fact_check(edition,{comment: "Review this guide please.", email_addresses: "test@test.com"})

    assert other_user.skip_fact_check(edition, {comment: 'Fact check not received in time'})
    edition.reload
    assert edition.can_publish?
    assert edition.actions.detect { |e| e.request_type == 'skip_fact_check' }
  end

  test "check counting reviews" do
    user = User.create(name: "Ben")
    other_user = User.create(name: "James")

    guide = user.create_edition(:guide, title: "My Title", slug: "my-title", panopticon_id: "12345")
    edition = guide

    assert_equal 0, guide.rejected_count

    user.start_work(edition)
    user.request_review(edition,{comment: "Review this guide please."})
    other_user.request_amendments(edition, {comment: "I've reviewed it"})

    assert_equal 1, guide.rejected_count

    user.request_review(edition,{comment: "Review this guide please."})
    other_user.approve_review(edition, {comment: "Looks good to me"})

    assert_equal 1, guide.rejected_count
  end

  test "user should not be able to review a guide they requested review for" do
    user = User.create(name: "Ben")

    guide = user.create_edition(:guide, title: "My Title", slug: "my-title", panopticon_id: "12345")
    edition = guide
    user.start_work(edition)
    assert edition.can_request_review?
    user.request_review(edition,{comment: "Review this guide please."})
    refute user.request_amendments(edition, {comment: "Well Done, but work harder"})
  end

  test "user should not be able to okay a guide they requested review for" do
    user = User.create(name: "Ben")

    guide = user.create_edition(:guide, title: "My Title", slug: "my-title", panopticon_id: "12345")
    edition = guide
    user.start_work(edition)
    assert edition.can_request_review?
    user.request_review(edition,{comment: "Review this guide please."})
    refute user.approve_review(edition, "")
  end

  test "a new programme has drafts but isn't published" do
    p = template_programme
    assert p.draft?
    refute p.published?
  end

  test "a programme should be marked as having reviewables if requested for review" do
    programme = template_programme
    user, other_user = template_users

    refute programme.in_review?
    user.request_review(programme, {comment: "Review this programme please."})
    assert programme.in_review?, "A review was not requested for this programme."
  end

  test "programme workflow" do
    user, other_user = template_users

    edition = user.create_edition(:programme, panopticon_id: 123, title: "My title", slug: "my-slug")
    user.start_work(edition)
    assert edition.can_request_review?
    user.request_review(edition,{comment: "Review this guide please."})
    refute edition.can_request_review?
    assert edition.can_request_amendments?
    other_user.request_amendments(edition, {comment: "I've reviewed it"})
    refute edition.can_request_amendments?
    user.request_review(edition,{comment: "Review this guide please."})
    assert edition.can_approve_review?
    other_user.approve_review(edition, {comment: "Looks good to me"})
    assert edition.can_publish?
  end

  test "user should not be able to okay a programme they requested review for" do
    user, other_user = template_users

    edition = user.create_edition(:programme, panopticon_id: 123, title: "My title", slug: "my-slug")
    user.start_work(edition)
    assert edition.can_request_review?
    user.request_review(edition,{comment: "Review this programme please."})
    refute user.approve_review(edition, "")
  end

  test "you can only create a new edition from a published edition" do
    user, other_user = template_users

    edition = user.create_edition(:programme, panopticon_id: 123, title: "My title", slug: "my-slug")
    refute edition.published?
    refute user.new_version(edition)
  end

  test "a new edition of an answer creates a diff when published" do
    without_metadata_denormalisation(AnswerEdition) do
      edition_one = AnswerEdition.new(title: "Chucking wood", slug: "woodchuck", panopticon_id: 1)
      edition_one.body = "A woodchuck would chuck all the wood he could chuck if a woodchuck could chuck wood."
      edition_one.state = :ready
      edition_one.save!

      user = User.create name: "Michael"
      user.publish edition_one, comment: "First edition"

      edition_two = edition_one.build_clone
      edition_two.body = "A woodchuck would chuck all the wood he could chuck if a woodchuck could chuck wood.\nAlthough no more than 361 cubic centimetres per day."
      edition_two.state = :ready
      edition_two.save!

      user.publish edition_two, comment: "Second edition"

      publish_action = edition_two.actions.where(request_type: "publish").last

      assert_equal "A woodchuck would chuck all the wood he could chuck if a woodchuck could chuck wood.{+\"\\nAlthough no more than 361 cubic centimetres per day.\"}", publish_action.diff
    end
  end
end
