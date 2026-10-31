# frozen_string_literal: true

module DiscourseGhostEmbeds
  # Rewrites what Ghost renders into what Discourse can keep. Core's embed import
  # only allows a short list of tags and replaces anything else with its text, so
  # an image inside <picture> disappears, and it drops the classes that say what a
  # card is. Hence this runs on the page before core reads it.
  module Cleaner
    GHOST_MARKUP = /<picture|kg-callout-card|kg-bookmark-card/
    VARIATION_SELECTOR = "️"

    # Ghost's callouts carry an emoji and a colour, not a meaning. Writers pick
    # the emoji for what they want to say, so it decides first.
    TYPE_BY_EMOJI = {
      "⚠" => "warning",
      "💡" => "tip",
      "ℹ" => "info",
      "🚨" => "danger",
      "❗" => "danger",
      "✅" => "success",
    }.freeze
    TYPE_BY_COLOR = {
      "blue" => "info",
      "green" => "success",
      "yellow" => "warning",
      "red" => "danger",
      "pink" => "danger",
    }.freeze
    DEFAULT_TYPE = "note"

    def self.before_import(html, url)
      text = html.dup.force_encoding(Encoding::UTF_8)
      return html if !text.valid_encoding? || !text.match?(GHOST_MARKUP)

      doc = Nokogiri.HTML5(text)
      host = URI.parse(UrlHelper.normalized_encode(url)).host
      doc.css("a[href]").each { |link| link["href"] = strip_ref(link["href"], host) }
      doc.css("picture").each { |picture| unwrap_picture(picture) }
      doc.css(".kg-bookmark-card").each { |card| rewrite_bookmark(card) }
      doc.css(".kg-callout-card").each { |card| rewrite_callout(card) }
      doc.to_html
    end

    # The onebox class is added here, not before the import, because core strips
    # every class that isn't in allowed_embed_classnames.
    def self.after_import(body)
      fragment = Nokogiri::HTML5.fragment(body)
      fragment
        .css("p > a[href]")
        .each do |link|
          next if link.parent.element_children.size > 1
          next if link.parent.text.strip != link.text.strip
          next if UrlHelper.normalized_encode(link.text.strip) != link["href"]

          link["class"] = "onebox"
        end
      fragment.to_html
    end

    # Ghost tags outgoing links with ?ref=<site>. Other parameters stay.
    def self.strip_ref(href, host)
      return href if host.blank?

      ref = "ref=#{Regexp.escape(host)}"
      href.sub(/\?#{ref}(?=#|\z)/, "").sub(/\?#{ref}&/, "?").sub(/&#{ref}(?=&|#|\z)/, "")
    end

    def self.unwrap_picture(picture)
      image = picture.at_css("img")
      image ? picture.replace(image) : picture.remove
    end

    # A link alone in its paragraph is what a onebox is made from.
    def self.rewrite_bookmark(card)
      href = card.at_css("a.kg-bookmark-container")&.[]("href")
      return if href.blank?

      doc = card.document
      paragraph = doc.create_element("p")
      paragraph.add_child(doc.create_element("a", UrlHelper.normalized_encode(href), href: href))
      caption = card.at_css("figcaption")
      card.add_previous_sibling(paragraph)
      if caption
        card.add_previous_sibling(
          doc.create_element("p").tap { |p| p.inner_html = caption.inner_html },
        )
      end
      card.remove
    end

    def self.rewrite_callout(card)
      text = card.at_css(".kg-callout-text")
      return if text.nil?

      doc = card.document
      emoji = card.at_css(".kg-callout-emoji")&.text.to_s.strip
      type = callout_type(emoji, card["class"])

      quote = doc.create_element("blockquote")
      quote.add_child(doc.create_element("p", "[!#{type}]"))
      paragraphs(text).each { |paragraph| quote.add_child(paragraph) }
      # An emoji we can't map says something the callout's icon won't.
      if emoji.present? && !TYPE_BY_EMOJI.key?(emoji.delete(VARIATION_SELECTOR))
        quote.element_children[1]&.prepend_child(doc.create_text_node("#{emoji} "))
      end
      card.replace(quote)
    end

    def self.callout_type(emoji, classes)
      color = classes.to_s[/kg-callout-card-([a-z]+)/, 1]
      TYPE_BY_EMOJI[emoji.delete(VARIATION_SELECTOR)] || TYPE_BY_COLOR[color] || DEFAULT_TYPE
    end

    # Callout text is inline with <br>, which core's import would drop.
    def self.paragraphs(text)
      doc = text.document
      current = doc.create_element("p")
      result = [current]
      text.children.to_a.each do |child|
        if child.name == "br"
          result << (current = doc.create_element("p")) if current.children.any?
        else
          current.add_child(child)
        end
      end
      result.select { |paragraph| paragraph.children.any? }
    end
    private_class_method :strip_ref,
                         :unwrap_picture,
                         :rewrite_bookmark,
                         :rewrite_callout,
                         :callout_type,
                         :paragraphs
  end
end
