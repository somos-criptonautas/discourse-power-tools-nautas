# frozen_string_literal: true

require "rails_helper"

# A room poll's backing post is readable only by the room: before, its
# holder was an unlisted public topic that anyone could open by id.
RSpec.describe "Disteleplus poll backing posts" do
  fab!(:member) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[1]) }
  fab!(:team) { Fabricate(:group).tap { |g| g.add(member) } }
  fab!(:public_category, :category)

  before do
    SiteSetting.jtech_enabled = true
    SiteSetting.disteleplus_enabled = true
    SiteSetting.disteleplus_polls_enabled = true
    SiteSetting.disteleplus_allowed_groups = team.id.to_s
  end

  def poll_message
    raw = "Pizza?\n\n[poll type=regular]\n* Yes\n* No\n[/poll]"
    DiscourseDisteleplus::Message.create!(user: member, raw: raw, cooked: "<p>Pizza?</p>")
  end

  def backing_post
    post = DiscourseDisteleplus::Polls.create_backing_post!(poll_message)
    expect(post).to be_present
    post
  end

  it "keeps the poll from visitors and members outside the room" do
    post = backing_post
    expect(post.topic.private_message?).to eq(true)

    get "/t/#{post.topic_id}.json"
    expect(response.status).not_to eq(200)
    get "/raw/#{post.topic_id}/#{post.post_number}"
    expect(response.status).not_to eq(200)

    sign_in(outsider)
    get "/posts/#{post.id}.json"
    expect(response.status).not_to eq(200)
  end

  it "still lets the room read and vote" do
    post = backing_post
    sign_in(member)

    get "/posts/#{post.id}.json"
    expect(response.status).to eq(200)

    option = Poll.find_by(post: post).poll_options.first
    put "/polls/vote.json",
        params: {
          post_id: post.id,
          poll_name: "poll",
          options: [option.digest],
        }
    expect(response.status).to eq(200)
  end

  it "makes an existing public holder private and follows the room's groups" do
    legacy = Fabricate(:topic, category: public_category, visible: false, closed: true)
    Fabricate(:post, topic: legacy)
    SiteSetting.disteleplus_polls_topic_id = legacy.id
    other_team = Fabricate(:group)
    SiteSetting.disteleplus_allowed_groups = other_team.id.to_s

    post = backing_post

    expect(post.topic_id).to eq(legacy.id)
    legacy.reload
    expect(legacy.private_message?).to eq(true)
    expect(legacy.category_id).to be_nil
    expect(legacy.topic_allowed_groups.pluck(:group_id)).to eq([other_team.id])
  end
end
