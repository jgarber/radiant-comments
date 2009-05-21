class AddPreferenceForSimpleSpamcheck < ActiveRecord::Migration
  def self.up
    if Radiant::Config.table_exists? && !Radiant::Config['comments.require_simple_spam_filter']
      Radiant::Config.create(:key => 'comments.require_simple_spam_filter', :value => true)
    end
  end
  
  def self.down
    # not necessary
  end
end

