module CommentTags
  include Radiant::Taggable

  desc "Provides tags and behaviors to support comments in Radiant."

  desc %{
    Renders the contained elements if comments are enabled on the page.
  }
  tag "if_enable_comments" do |tag|
    tag.expand if (tag.locals.page.enable_comments?)
  end
  # makes more sense to me
  tag "if_comments_enabled" do |tag|
    tag.expand if (tag.locals.page.enable_comments?)
  end

  desc %{
    Renders the contained elements unless comments are enabled on the page.
  }
  tag "unless_enable_comments" do |tag|
    tag.expand unless (tag.locals.page.enable_comments?)
  end

  # makes more sense to me
  tag "unless_comments_enabled" do |tag|
    tag.expand unless (tag.locals.page.enable_comments?)
  end

  desc %{
    Renders the contained elements if the page has comments.
  }
  tag "if_comments" do |tag|
    tag.expand if tag.locals.page.has_visible_comments?
  end

  desc %{
    Renders the contained elements unless the page has comments.
  }
  tag "unless_comments" do |tag|
    tag.expand unless tag.locals.page.has_visible_comments?
  end

  desc %{
    Renders the contained elements if the page has comments _or_ comment is enabled on it.
  }
  tag "if_comments_or_enable_comments" do |tag|
    tag.expand if(tag.locals.page.has_visible_comments? || tag.locals.page.enable_comments?)
  end

  desc %{
    Gives access to comment-related tags
  }
  tag "comments" do |tag|
    comments = tag.locals.page.approved_ordered_comments
    tag.expand
  end

  desc %{
    Cycles through each comment and renders the enclosed tags for each.
  }
  tag "comments:each" do |tag|
    page = tag.locals.page
    limit = tag.attr['limit'] || 10
    offset = tag.attr['offset'] || 0
    comments = page.approved_ordered_comments.find(:all, :limit => limit, :offset => offset)
    result = []
    comments.each_with_index do |comment, index|
      tag.locals.comment = comment
      tag.locals.index = index
      result << tag.expand
    end
    result
  end

  desc %{
    Gives access to the particular fields for each comment.
  }
  tag "comments:field" do |tag|
    tag.expand
  end

  desc %{
    Renders the index number for this comment.
  }
  tag 'comments:field:index' do |tag|
    tag.locals.index + 1
  end

  %w(id author author_email author_url content content_html filter_id rating).each do |field|
    desc %{ Print the value of the #{field} field for this comment. }
    tag "comments:field:#{field}" do |tag|
      options = tag.attr.dup
      #options.inspect
      value = tag.locals.comment.send(field)
      return value[7..-1] if field == 'author_url' && value[0,7]=='http://'
      value
    end
  end

  desc %{
    Renders the date a comment was created.

    *Usage:*
    <pre><code><r:date [format="%A, %B %d, %Y"] /></code></pre>
  }
  tag 'comments:field:date' do |tag|
    comment = tag.locals.comment
    format = (tag.attr['format'] || '%A, %B %d, %Y')
    date = comment.created_at
    date.strftime(format)
  end

  desc %{
    Renders a link if there's an author_url, otherwise just the author's name.
  }
  tag "comments:field:author_link" do |tag|
    if tag.locals.comment.author_url.blank?
      tag.locals.comment.author
    else
      %(<a href="http://#{tag.locals.comment.author_url}">#{tag.locals.comment.author}</a>)
    end
  end

  desc %{
    Renders the contained elements if the comment has an author_url specified.
  }
  tag "comments:field:if_author_url" do |tag|
    tag.expand unless tag.locals.comment.author_url.blank?
  end

  desc %{
    Renders the contained elements if the comment is selected - that is, if it is a comment
    the user has just posted
  }
  tag "comments:field:if_selected" do |tag|
    tag.expand if tag.locals.comment == tag.locals.page.selected_comment
  end

  desc %{
    Renders the contained elements if the comment has been approved
  }
  tag "comments:field:if_approved" do |tag|
    tag.expand if tag.locals.comment.approved?
  end

  desc %{
    Renders the containing markup for each score of the rating

    Example:
      <r:comments:field:rating_empty_star>*</r:comments:field:rating_empty_star>
  }
  tag 'comments:field:rating_empty_star' do |tag|
    @empty_star = tag.expand
    ''
  end

  desc %{
    Renders the containing markup for each score of the rating

    Example:
      <r:comments:field:rating_full_star>*</r:comments:field:rating_full_star>
  }
  tag 'comments:field:rating_full_star' do |tag|
    rating = tag.locals.comment.rating || Comment::MIN_RATING
    markup = ''
    rating.times { markup << tag.expand }
    (Comment::MAX_RATING - rating).times { markup << @empty_star.to_s }
    markup
  end

  desc %{
    Renders the contained elements if the comment has not been approved
  }
  tag "comments:field:unless_approved" do |tag|
    tag.expand unless tag.locals.comment.approved?
  end

  desc %{
    Renders a Gravatar URL for the author of the comment.
  }
  tag "comments:field:gravatar_url" do |tag|
    email = tag.locals.comment.author_email
    size = tag.attr['size']
    format = tag.attr['format']
    rating = tag.attr['rating']
    default = tag.attr['default']
    md5 = Digest::MD5.hexdigest(email)
    returning "http://www.gravatar.com/avatar/#{md5}" do |url|
      url << ".#{format.downcase}" if format
      if size || rating || default
        attrs = []
        attrs << "s=#{size}" if size
        attrs << "d=#{default}" if default
        attrs << "r=#{rating.downcase}" if rating
        url << "?#{attrs.join('&')}"
      end
    end
  end

  desc %{
    Renders a comment form.

    *Usage:*
    <r:comment:form [class="comments" id="comment_form"]>...</r:comment:form>
  }
  tag "comments:form" do |tag|
    attrs = tag.attr.symbolize_keys
    html_class, html_id = attrs[:class], attrs[:id]
    r = %Q{ <form action="#{tag.locals.page.url}comments}
      r << %Q{##{html_id}} unless html_id.blank?
    r << %{" method="post" } #comlpete the quotes for the action
      r << %{ id="#{html_id}" } unless html_id.blank?
      r << %{ class="#{html_class}" } unless html_class.blank?
    r << '>' #close the form element
    r << %{<input type="hidden" name="comment[occupado]" value="" />}
    r << %{<input type="hidden" name="comment[miel]" value="" />}
    r <<  tag.expand
    r << %{</form>}
    r
  end

  tag 'comments:error' do |tag|
    if comment = tag.locals.page.last_comment
      if on = tag.attr['on']
        if error = comment.errors.on(on)
          tag.locals.error_message = error
          tag.expand
        end
      else
        tag.expand if !comment.valid?
      end
    end
  end

  tag 'comments:error:message' do |tag|
    tag.locals.error_message
  end

  %w(text password hidden).each do |type|
    desc %{Builds a #{type} form field for comments.}
    tag "comments:#{type}_field_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      r = %{<input type="#{type}"}
      r << %{ id="comment_#{attrs[:name]}"}
      r << %{ name="comment[#{attrs[:name]}]"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      if value = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(attrs[:name]) : attrs[:value])
        r << %{ value="#{value}" }
      end
      r << %{ />}
    end
  end

  %w(submit reset).each do |type|
    desc %{Builds a #{type} form button for comments.}
    tag "comments:#{type}_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      r = %{<input type="#{type}"}
      r << %{ id="#{attrs[:name]}"}
      r << %{ name="#{attrs[:name]}"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      r << %{ value="#{attrs[:value]}" } if attrs[:value]
      r << %{ />}
    end
  end

  desc %{Builds a text_area form field for comments.}
  tag "comments:text_area_tag" do |tag|
    attrs = tag.attr.symbolize_keys
    r = %{<textarea}
    r << %{ id="comment_#{attrs[:name]}"}
    r << %{ name="comment[#{attrs[:name]}]"}
    r << %{ class="#{attrs[:class]}"} if attrs[:class]
    r << %{ rows="#{attrs[:rows]}"} if attrs[:rows]
    r << %{ cols="#{attrs[:cols]}"} if attrs[:cols]
    r << %{>}
    if content = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(attrs[:name]) : attrs[:content])
      r << content
    end
    r << %{</textarea>}
  end

  desc %{Build a drop_box form field for the filters avaiable.}
  tag "comments:filter_box_tag" do |tag|
    attrs = tag.attr.symbolize_keys
    value = attrs.delete(:value)
    name = attrs.delete(:name)
    r =  %{<select name="comment[#{name}]"}
    unless attrs.empty?
      r << " "
      r << attrs.map {|k,v| %Q(#{k}="#{v}") }.join(" ")
    end
    r << %{>}

    TextFilter.descendants.each do |filter|

      r << %{<option value="#{filter.filter_name}"}
      r << %{ selected="selected"} if value == filter.filter_name
      r << %{>#{filter.filter_name}</option>}

    end

    r << %{</select>}
  end


  desc %{Builds a series of input tags to input a rating

    *Usage:*
    <pre><code><r:comments:ratings_tag [class="myclass"] [disabled="disabled"] /></code></pre>
  }
  tag 'comments:ratings_tag' do |tag|
    module TagCreator
      # Hack, simply including modules in CommentTags didn't work
      extend ActionView::Helpers::TagHelper
      extend ActionView::Helpers::FormTagHelper
    end
    returning '' do |markup|
      (Comment::MIN_RATING...Comment::MAX_RATING).each do |rating|
        markup << TagCreator.radio_button_tag('comment[rating]', rating+1, false, tag.attr)
      end
    end
  end

  desc %{Prints the number of comments. }
  tag "comments:count" do |tag|
    tag.locals.page.approved_comments.count
  end

  tag "recent_comments" do |tag|
    tag.expand
  end

  desc %{Returns the last [limit] comments throughout the site.

    *Usage:*
    <pre><code><r:recent_comments:each [limit="10"]>...</r:recent_comments:each></code></pre>
    }
  tag "recent_comments:each" do |tag|
    limit = tag.attr['limit'] || 10
    comments = Comment.find(:all, :conditions => "comments.approved_at IS NOT NULL", :order => "created_at DESC", :limit => limit)
    result = []
    comments.each_with_index do |comment, index|
      tag.locals.comment = comment
      tag.locals.index = index
      tag.locals.page = comment.page
      result << tag.expand
    end
    result
  end

  desc %{
    Use this to prevent spam bots from filling your site with spam.

    *Usage:*
    <pre><code>What day comes after Monday? <r:comments:spam_answer_tag answer="Tuesday" /></code></pre>
  }
  tag "comments:spam_answer_tag" do |tag|
      attrs = tag.attr.symbolize_keys
      valid_spam_answer = attrs[:answer] || 'hemidemisemiquaver'
      r = %{<input type="text" id="comment_spam_answer" name="comment[spam_answer]"}
      r << %{ class="#{attrs[:class]}"} if attrs[:class]
      if value = (tag.locals.page.last_comment ? tag.locals.page.last_comment.send(:spam_answer) : '')
        r << %{ value="#{value}" }
      end
      r << %{ />}
      r << %{<input type="hidden" name="comment[valid_spam_answer]" value="#{valid_spam_answer}" />}
  end

  desc %{
    Show the contents if a comment was just selected

    *Usage*
    <pre><code><r:comments:if_selected /></code></pre>
  }
  tag "comments:if_selected" do |tag|
    tag.expand if tag.locals.page.selected_comment
  end
end
