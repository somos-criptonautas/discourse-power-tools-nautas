# frozen_string_literal: true

module DiscourseGhostEmbeds
  module TopicEmbedExtension
    # **options, because core's signature varies between versions.
    def parse_html(html, url, **options)
      return super unless DiscourseGhostEmbeds.enabled?

      response = super(Cleaner.before_import(html, url), url, **options)
      response.body = Cleaner.after_import(response.body)
      response
    end
  end
end
