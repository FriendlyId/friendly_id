class DefaultScopeTest < MiniTest::Unit::TestCase

  include FriendlyId::Test

  class OrderedJournalist < ActiveRecord::Base
    extend FriendlyId
    friendly_id :name, :use => :slugged
    default_scope :order => 'position ASC', :conditions => { :department => 'main_service' }
  end
  
  test "friendly_id should sequence correctly a default_scoped ordered table" do
    OrderedJournalist.delete_all
    OrderedJournalist.create!({ :name => 'I\'m unique', :position => 1, :department => 'main_service' })
    OrderedJournalist.create!({ :name => 'I\'m unique', :position => 2, :department => 'main_service' })
    begin
      OrderedJournalist.create!({ :name => 'I\'m unique', :position => 3, :department => 'main_service' }) # should not raise ActiveRecord::RecordNotUnique: SQLite3::ConstraintException: column slug is not unique: INSERT INTO "ordered_journalists" ("name", "active", "slug", "position") VALUES ('I''m unique', NULL, 'i-m-unique--2', 3)
    rescue
      flunk "expected no errors but got #{$!}"
    end
  end
  
  test "friendly_id should sequence correctly a default_scoped scoped table" do
    OrderedJournalist.delete_all
    OrderedJournalist.create!({ :name => 'I\'m unique', :department => 'other_service' })
    begin
      OrderedJournalist.create!({ :name => 'I\'m unique', :department => 'main_service' }) # should not raise ActiveRecord::RecordNotUnique: SQLite3::ConstraintException: column slug is not unique: INSERT INTO "ordered_journalists" ("name", "active", "slug", "position", "department") VALUES ('I''m unique', NULL, 'i-m-unique', 1, 'main_service')
    rescue
      flunk "expected no errors but got #{$!}"
    end
  end
end
