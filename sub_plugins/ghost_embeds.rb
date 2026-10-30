# frozen_string_literal: true
# Jtech sub-plugin: Ghost embeds — makes blog posts imported from Ghost through
# core's Embedding keep their images, callouts and link cards.
# Instance_eval'd by plugin.rb in the Plugin::Instance context.
#
# Settings (config/settings.yml, jtech_ghost_embeds):
#   ghost_embeds_enabled  module switch

module ::DiscourseGhostEmbeds
  def self.enabled?
    SiteSetting.jtech_enabled && SiteSetting.ghost_embeds_enabled
  end
end

require_relative "../lib/discourse_ghost_embeds/cleaner"
require_relative "../lib/discourse_ghost_embeds/topic_embed_extension"

after_initialize do
  reloadable_patch { TopicEmbed.singleton_class.prepend(DiscourseGhostEmbeds::TopicEmbedExtension) }
end
