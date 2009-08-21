class Comment < ActiveRecord::Base
  belongs_to :page

  acts_as_list :scope => 'page_id = #{page_id} AND approved = 1'

  # validate :validate_spam_answer
  validates_presence_of :author, :author_email, :content, :page
  MIN_RATING = 0
  MAX_RATING = 5
  validates_inclusion_of :rating, :in => MIN_RATING..MAX_RATING, :allow_blank => true
  
  before_save :auto_approve
  before_save :apply_filter
  # after_save  :save_mollom_servers
    
  attr_accessor :valid_spam_answer, :spam_answer
  attr_accessible :author, :author_email, :author_url, :filter_id, :content, :rating, :valid_spam_answer, :spam_answer
  
  def self.per_page
    50
  end
  
  def request=(request)
    self.author_ip = request.remote_ip
    self.user_agent = request.env['HTTP_USER_AGENT']
    self.referrer = request.env['HTTP_REFERER']
  end
  
  def akismet
    @akismet ||= Akismet.new(Radiant::Config['comments.akismet_key'], Radiant::Config['comments.akismet_url'])
  end
  
  def save_mollom_servers
    Rails.cache.write('MOLLOM_SERVER_CACHE', mollom.server_list.to_yaml) if mollom.key_ok?
  rescue Mollom::Error #TODO: something with this error...
  end
  
  def mollom
    return @mollom if @mollom
    @mollom ||= Mollom.new(:private_key => Radiant::Config['comments.mollom_privatekey'], :public_key => Radiant::Config['comments.mollom_publickey'])
    unless Rails.cache.read('MOLLOM_SERVER_CACHE').blank?
      @mollom.server_list = YAML::load(Rails.cache.read('MOLLOM_SERVER_CACHE'))
    end    
    @mollom
  end
  
  # If the Akismet details are valid, and Akismet thinks this is a non-spam
  # comment, this method will return true
  def auto_approve?
    #override
    return false
    if passes_simple_spam_filter?
      true
    elsif akismet.valid?
      # We do the negation because true means spam, false means ham
      !akismet.commentCheck(
        self.author_ip,            # remote IP
        self.user_agent,           # user agent
        self.referrer,             # http referer
        self.page.url,             # permalink
        'comment',                 # comment type
        self.author,               # author name
        self.author_email,         # author email
        self.author_url,           # author url
        self.content,              # comment text
        {}                         # other
      )
      elsif mollom.key_ok?
        response = mollom.check_content(
          :author_name => self.author,            # author name     
          :author_mail => self.author_email,         # author email
          :author_url => self.author_url,           # author url
          :post_body => self.content              # comment text
          )
          ham = response.ham?
          self.mollom_id = response.session_id
       response.ham?  
    else
      false
    end
  rescue Mollom::Error
    return false
  end
  
  def unapproved?
    !approved?
  end
  
  def ap_status
    if approved?
      "approved"
    else
      "unapproved"
    end
  end

  def approve
    self.approved = true
    self.approved_at = Time.now
    add_to_list_bottom
  end

  def approve!
    self.update_attribute(:approved, true)
    self.update_attribute(:approved_at, Time.now)
    add_to_list_bottom
    save!
  end
  
  def unapprove!
    self.update_attribute(:approved_at, nil)
    self.update_attribute(:approved, false)
    add_to_list_bottom
    save!
    # if we have to unapprove, and use mollom, it means
    # the initial check was false. Submit this to mollom as Spam.
    # Ideally, we'd need a different feedback for
    #  - spam
    #  - profanity
    #  - unwanted
    #  - low-quality
    #  begin
    #  if mollom.key_ok? and !self.mollom_id.empty?
    #     mollom.send_feedback :session_id => self.mollom_id, :feedback => 'spam'
    #   end
    # rescue Mollom::Error => e
    #   raise Comment::AntispamWarning.new(e.to_s)
    # end
  end
  
  private
  
    def validate_spam_answer
      unless passes_simple_spam_filter?
        self.errors.add :spam_answer, "is not correct."
      end
    end
    
    def passes_simple_spam_filter?
      if !self.valid_spam_answer.blank? && self.valid_spam_answer.to_s.downcase.slugify == self.spam_answer.to_s.downcase.slugify
        true
      else
        false
      end
    end

    def auto_approve
      approve if auto_approve?
    end
    
    def apply_filter
      self.content_html = filter.filter(content)
    end
    
    def filter
      filtering_enabled? && filter_from_form || SimpleFilter.new
    end
    
    def filter_from_form
      TextFilter.descendants.find { |f| f.filter_name == filter_id }
    end
    
    def filtering_enabled?
      Radiant::Config['comments.filters_enabled'] == "true"
    end
  
  class SimpleFilter
    include ERB::Util
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::TagHelper
    
    def filter(content)
      simple_format(h(content))
    end
  end
  
  class AntispamWarning < StandardError; end
end
