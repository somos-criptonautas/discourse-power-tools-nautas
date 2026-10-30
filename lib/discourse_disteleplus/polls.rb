# frozen_string_literal: true

module DiscourseDisteleplus
  # Native polls in the conversation, powered entirely by core's poll plugin.
  #
  # A conversation message whose raw contains [poll] markup gets a BACKING
  # POST in a hidden holder topic; that post's markup creates real ::Poll
  # rows, voting goes through core's /polls/vote endpoints (standard guardian
  # checks against the backing post), results stream over core's
  # /polls/<topic_id> MessageBus channel, and the conversation renders its
  # own widget from the serialized poll. Telegram receives the question plus
  # a deep link to vote here — bots cannot vote in Telegram's native widget,
  # so the forum poll is the single source of truth (no fake parity).
  #
  # The backing post is created with skip_validations (the holder topic is
  # closed) and polls are then extracted with post.validate_polls(true) —
  # the same force path core uses for approved queued posts.
  module Polls
    POLL_MARKUP = /\[poll(\s[^\]]*)?\]/
    STRIP_POLL = %r{\[poll(\s[^\]]*)?\].*?\[/poll\]}m

    def self.enabled?
      !!(
        DiscourseDisteleplus.enabled? && SiteSetting.disteleplus_polls_enabled &&
          defined?(::DiscoursePoll)
      )
    end

    def self.poll_markup?(raw)
      raw.to_s.match?(POLL_MARKUP)
    end

    def self.holder_topic
      topic = ::Topic.find_by(id: SiteSetting.disteleplus_polls_topic_id)
      topic = create_holder_topic if topic.nil? || topic.trashed?
      restrict_to_room!(topic)
      topic
    end

    # A message for the room's groups, not a public topic: unlisted alone
    # still lets anyone read the polls by URL. Admins see it as they see every
    # message. Synced on each poll so it follows disteleplus_allowed_groups.
    def self.restrict_to_room!(topic)
      unless topic.private_message?
        topic.update_columns(archetype: Archetype.private_message, category_id: nil)
      end
      group_ids = Access.allowed_group_ids
      topic.topic_allowed_groups.where.not(group_id: group_ids).delete_all
      (group_ids - topic.topic_allowed_groups.pluck(:group_id)).each do |group_id|
        topic.topic_allowed_groups.create!(group_id: group_id)
      end
    end

    # Uncategorized is frequently disallowed (TopicCreator rejects it even
    # under skip_validations), so the holder lands in the first public
    # category — it is unlisted either way.
    def self.holder_category_id
      Category
        .where(read_restricted: false)
        .where.not(id: SiteSetting.uncategorized_category_id)
        .order(:id)
        .pick(:id) || SiteSetting.uncategorized_category_id
    end

    def self.create_holder_topic
      post =
        PostCreator.create!(
          Discourse.system_user,
          title: "Disteleplus conversation polls",
          raw:
            "Backing posts for polls created in the /disteleplus conversation. " \
              "Votes live on these posts; the conversation renders them.",
          category: holder_category_id,
          skip_validations: true,
        )
      topic = post.topic
      # Unlisted so it never surfaces in lists, closed so nobody replies by
      # hand. holder_topic then makes it a message for the room.
      topic.update_columns(visible: false, closed: true)
      SiteSetting.disteleplus_polls_topic_id = topic.id
      topic
    end

    # Returns the backing post, or nil when the markup does not validate as
    # a poll (the message then renders as plain text — same as a bad [poll]
    # block in a regular post draft).
    def self.create_backing_post!(message)
      return nil unless enabled?
      return nil unless poll_markup?(message.raw)

      post =
        PostCreator.create!(
          message.user || Discourse.system_user,
          topic_id: holder_topic.id,
          raw: message.raw,
          skip_validations: true,
          # The room notifies on its own; a post alert would message every
          # member of the room's groups about each poll.
          skip_jobs: true,
        )
      post.validate_polls(true)

      poll = ::Poll.find_by(post: post)
      if poll
        message.update_columns(poll_post_id: post.id)
        # post_created fired before the polls existed (they come from the
        # forced validation above), so core never scheduled the auto-close
        # job — schedule it now, plus our results announcement just after.
        ::DiscoursePoll::Poll.schedule_jobs(post)
        if poll.close_at.present?
          Jobs.enqueue_at(
            poll.close_at + 90.seconds,
            :disteleplus_poll_close_announcement,
            message_id: message.id,
          )
        end
        post
      else
        PostDestroyer.new(Discourse.system_user, post).destroy
        nil
      end
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} poll backing post failed: #{e.message}")
      nil
    end

    def self.destroy_backing_post(message)
      return if message.poll_post_id.blank?
      post = ::Post.find_by(id: message.poll_post_id)
      PostDestroyer.new(Discourse.system_user, post).destroy if post
    rescue StandardError => e
      Rails.logger.warn("#{DiscourseDisteleplus::LOG_TAG} poll cleanup failed: #{e.message}")
    end

    # The message text with the [poll] block removed — the question, usually.
    def self.question_text(raw)
      raw.to_s.sub(STRIP_POLL, "").strip
    end

    def self.serialize(message, viewer)
      return nil if message.poll_post_id.blank?
      post = ::Post.find_by(id: message.poll_post_id)
      poll = post && ::Poll.includes(:poll_options).find_by(post: post)
      return nil unless poll

      counts = ::PollVote.where(poll: poll).group(:poll_option_id).count
      my_option_ids =
        (viewer ? ::PollVote.where(poll: poll, user_id: viewer.id).pluck(:poll_option_id) : [])

      # Who picked what — public polls only (the builder always sets
      # public=true; a hand-written secret poll stays secret).
      voters_by_digest = (poll.everyone? ? ::DiscoursePoll::Poll.serialized_voters(poll) || {} : {})

      {
        post_id: post.id,
        topic_id: post.topic_id,
        name: poll.name,
        type: poll.type.to_s,
        status: poll.status.to_s,
        closed: !poll.open?,
        close_at: poll.close_at&.iso8601,
        public: poll.everyone?,
        voters: ::PollVote.where(poll: poll).distinct.count(:user_id),
        options:
          poll.poll_options.map do |option|
            {
              id: option.digest,
              html: option.html,
              votes: counts[option.id].to_i,
              chosen: my_option_ids.include?(option.id),
              voters: serialize_option_voters(voters_by_digest[option.digest]),
            }
          end,
      }
    end

    def self.serialize_option_voters(voters)
      Array(voters).map do |voter|
        voter = voter.with_indifferent_access if voter.respond_to?(:with_indifferent_access)
        {
          id: voter[:id],
          username: voter[:username],
          name: voter[:name],
          avatar_template: voter[:avatar_template],
        }
      end
    end

    # Markdown results summary for the close announcement message.
    def self.results_markdown(message)
      data = serialize(message, nil)
      return nil unless data

      total = data[:options].sum { |option| option[:votes] }
      lines = ["📊 **Poll closed:** #{question_text(message.raw).presence || "poll"}"]
      data[:options]
        .sort_by { |option| -option[:votes] }
        .each do |option|
          percent = total.positive? ? ((option[:votes] * 100.0) / total).round : 0
          text = option[:html].to_s.gsub(/<[^>]+>/, "").strip
          lines << "- #{text} — **#{option[:votes]}** (#{percent}%)"
        end
      lines << ""
      lines << "#{data[:voters]} voters"
      lines.join("\n")
    end
  end
end
