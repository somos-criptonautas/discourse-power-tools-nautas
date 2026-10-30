# frozen_string_literal: true

# The room's polls lived in an unlisted public topic, readable by anyone with
# its id. Makes it a message for the room's groups now rather than on the
# next poll (DiscourseDisteleplus::Polls.restrict_to_room! keeps it so).
class MakeDisteleplusPollHolderPrivate < ActiveRecord::Migration[7.2]
  def up
    topic_id =
      DB
        .query_single("SELECT value FROM site_settings WHERE name = 'disteleplus_polls_topic_id'")
        .first
        .to_i
    return if topic_id.zero?

    # Unset means the setting's default, the staff group.
    groups =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'disteleplus_allowed_groups'",
      ).first || "3"
    group_ids = groups.split("|").map(&:to_i).reject(&:zero?)

    execute(<<~SQL)
      UPDATE topics SET archetype = 'private_message', category_id = NULL
      WHERE id = #{topic_id}
    SQL
    group_ids.each { |group_id| execute(<<~SQL) }
      INSERT INTO topic_allowed_groups (topic_id, group_id)
      SELECT #{topic_id}, id FROM groups WHERE id = #{group_id}
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
