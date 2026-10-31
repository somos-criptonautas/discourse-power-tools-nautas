# frozen_string_literal: true

RSpec.describe DiscourseGhostEmbeds::Cleaner do
  fab!(:user)

  let(:url) { "https://blog.example.com/article/" }
  let(:page) { <<~HTML }
    <!doctype html><html><head><title>Article</title></head><body>
    <section class="gh-content">
      <p>A first paragraph long enough for the importer to treat this as the article, with some more words in it.</p>
      <p>Read <a href="https://example.org/a?ref=blog.example.com&amp;x=1">this</a> and <a href="https://example.org/b?ref=blog.example.com">that</a>, then keep going for a while.</p>
      <figure class="kg-card kg-image-card kg-card-hascaption">
        <picture>
          <source srcset="https://cdn.example.com/a.avif" type="image/avif">
          <img src="https://cdn.example.com/a.png" class="kg-image" alt="A screenshot">
        </picture>
        <figcaption>The caption</figcaption>
      </figure>
      <div class="kg-card kg-callout-card kg-callout-card-white">
        <div class="kg-callout-emoji">⚠️</div>
        <div class="kg-callout-text"><b><strong>Careful</strong></b> with this.<br><br>Second line.</div>
      </div>
      <div class="kg-card kg-callout-card kg-callout-card-green">
        <div class="kg-callout-emoji">🎯</div>
        <div class="kg-callout-text">Aim here.</div>
      </div>
      <figure class="kg-card kg-bookmark-card">
        <a class="kg-bookmark-container" href="https://example.org/card?ref=blog.example.com">
          <div class="kg-bookmark-content"><div class="kg-bookmark-title">Card title</div></div>
        </a>
      </figure>
      <p>A closing paragraph with enough words in it to keep the importer happy about this article.</p>
    </section>
    </body></html>
  HTML

  def imported
    TopicEmbed.parse_html(page.dup, url).body
  end

  context "when enabled" do
    before do
      SiteSetting.jtech_enabled = true
      SiteSetting.ghost_embeds_enabled = true
    end

    it "keeps images that Ghost wraps in picture" do
      expect(imported).to include('src="https://cdn.example.com/a.png"')
      expect(imported).to include("The caption")
    end

    it "turns callouts into marked blockquotes, by emoji and then colour" do
      quotes = Nokogiri::HTML5.fragment(imported).css("blockquote")

      expect(quotes.map { |quote| quote.at_css("p").text }).to eq(%w[[!warning] [!success]])
      expect(quotes.first.css("p").map(&:text)).to eq(
        ["[!warning]", "Careful with this.", "Second line."],
      )
      expect(quotes.last.css("p").last.text).to eq("🎯 Aim here.")
    end

    it "turns link cards into links that get oneboxed" do
      link = Nokogiri::HTML5.fragment(imported).at_css("a.onebox")

      expect(link["href"]).to eq("https://example.org/card")
      expect(link.text).to eq("https://example.org/card")
      expect(imported).not_to include("Card title")
    end

    it "does not onebox a link that sits in a sentence" do
      expect(Nokogiri::HTML5.fragment(imported).css("a.onebox").size).to eq(1)
    end

    it "removes the site's ref and keeps other parameters" do
      expect(imported).to include("https://example.org/a?x=1")
      expect(imported).to include('href="https://example.org/b"')
      expect(imported).not_to include("ref=blog.example.com")
    end

    it "leaves another site's ref alone" do
      html = page.gsub("ref=blog.example.com", "ref=other.example.com")

      expect(TopicEmbed.parse_html(html, url).body).to include("ref=other.example.com")
    end

    it "imports the cleaned article as the topic's post" do
      SiteSetting.embed_truncate = false
      post = TopicEmbed.import(user, url, "An article", imported)

      expect(post.cooked).to include("[!warning]")
      expect(post.cooked).to include('src="https://cdn.example.com/a.png"')
      expect(post.cooked).to include('class="onebox"')
    end

    it "does not reparse pages without Ghost's markup" do
      html = "<html><body><p>Nothing to do here.</p></body></html>"

      expect(described_class.before_import(html, url)).to equal(html)
    end
  end

  context "when off" do
    before do
      SiteSetting.jtech_enabled = true
      SiteSetting.ghost_embeds_enabled = false
    end

    it "leaves core's import as it was" do
      expect(imported).not_to include("https://cdn.example.com/a.png")
      expect(imported).not_to include("<blockquote")
    end
  end
end
