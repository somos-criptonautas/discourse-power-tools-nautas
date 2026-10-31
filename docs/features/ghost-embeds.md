# Ghost embeds

For forums that import posts from a Ghost blog with Discourse's Embedding. Core's import only keeps a short list of tags and drops the classes that say what a card is, so a Ghost article loses its images and its cards arrive as loose text. This module rewrites the page before core reads it:

- Images inside `<picture>` are kept.
- Callouts become `[!type]` quotes, shown as callouts by the [Quote Callouts](https://meta.discourse.org/t/quote-callouts/350962) theme component. The emoji decides the type, then the colour. Without that component they show as quotes with the marker visible.
- Link cards become links that Discourse oneboxes.
- The `?ref=<your blog>` Ghost adds to links is removed.

It only applies to new imports. To fix a topic already imported, import it again from the Rails console:

```ruby
user = User.find_by_username(SiteSetting.embed_by_username.presence || Discourse.system_user.username)
TopicEmbed.where(topic_id: [123]).find_each { |embed| TopicEmbed.import_remote(embed.embed_url, user: user) }
```

It overrides `TopicEmbed.parse_html` in core, so a Discourse update can break it; the specs in `spec/lib/discourse_ghost_embeds/` catch that.

## Settings

Admin → Plugins → Jtech Tools → **Ghost embeds**. The full text of each setting is shown next to it in the admin.

| Setting | Default | What it does |
| --- | --- | --- |
| `ghost_embeds_enabled` | `false` | Rewrites Ghost's images, callouts and link cards when a blog post is imported through Embedding. |

[← All features](../README.md#features)
