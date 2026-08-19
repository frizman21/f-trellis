require "uri"

module ApplicationHelper
  EXTERNAL_LINK_ICON = <<~SVG.html_safe.freeze
    <svg xmlns="http://www.w3.org/2000/svg" width="0.85em" height="0.85em"
         fill="currentColor" viewBox="0 0 16 16"
         aria-hidden="true" focusable="false"
         style="vertical-align: -0.05em; margin-left: 0.25em;">
      <path fill-rule="evenodd" d="M8.636 3.5a.5.5 0 0 0-.5-.5H1.5A1.5 1.5 0 0 0 0 4.5v10A1.5 1.5 0 0 0 1.5 16h10a1.5 1.5 0 0 0 1.5-1.5V7.864a.5.5 0 0 0-1 0V14.5a.5.5 0 0 1-.5.5h-10a.5.5 0 0 1-.5-.5v-10a.5.5 0 0 1 .5-.5h6.636a.5.5 0 0 0 .5-.5"/>
      <path fill-rule="evenodd" d="M16 .5a.5.5 0 0 0-.5-.5h-5a.5.5 0 0 0 0 1h3.793L6.146 9.146a.5.5 0 1 0 .708.708L15 1.707V5.5a.5.5 0 0 0 1 0z"/>
    </svg>
  SVG

  # Renders an anchor to an external URL with target=_blank, safe rel attrs,
  # and a small icon indicating it opens in a new tab.
  def external_link_to(text, url, **options)
    options = options.merge(
      target: "_blank",
      rel: [ options[:rel], "noopener", "noreferrer" ].compact.join(" ")
    )
    link_to(url, **options) { safe_join([ text.to_s, EXTERNAL_LINK_ICON ]) }
  end

  # An attribute value that is a web address, rendered as a link; anything else
  # rendered as text.
  #
  # Read off the value rather than declared on the attribute: the ontology has
  # no URL type, and asking whoever defines an entity type to classify each
  # string as prose or address is a decision they would get wrong and would have
  # to revisit every time an extraction recorded something new.
  #
  # Truncating happens here rather than in the view, because a shortened href is
  # a broken one: what is shown is cut, what is linked is whole.
  # `truncate: nil` shows the value whole — what an entity's own page does, where
  # there is one value per row and no column width to protect.
  def value_as_link(raw, truncate: 60)
    text = raw.to_s.strip
    shown = truncate ? text.truncate(truncate) : text
    return shown unless web_address?(text)

    external_link_to(shown, text)
  end

  # Deliberately narrow. http and https with a host, and nothing else: a bare
  # `acme.example` is far more often a part number, a filename or a version than
  # an address somebody meant to be clickable. Being wrong this way costs a
  # click; being wrong the other way puts a broken link in front of a reader.
  def web_address?(text)
    uri = URI.parse(text.to_s.strip)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  # The commit the running process was built from, for the navbar.
  #
  # Takes what it renders as arguments so both branches are reachable without
  # stubbing AppVersion — the working tree always has a .git in development and
  # test, so the unresolvable case cannot be reached through the environment.
  def running_version_badge(short: AppVersion.short, commit_url: AppVersion.commit_url)
    # text-white-50 rather than a *-emphasis utility: those resolve to dark text
    # for light backgrounds unless data-bs-theme="dark" is set, which it is not
    # here, and this sits on the dark navbar.
    if short.blank?
      return tag.span("version unknown",
                      class: "text-white-50 small me-3",
                      title: "Could not determine the running commit")
    end

    link_to short, commit_url,
            class: "text-white-50 small font-monospace text-decoration-none me-3",
            title: "Running commit — open on GitHub"
  end

  # Whether the navigation sidebar should render.
  #
  # Signed-out pages have never had one. A signed-in page opts out by setting
  # `content_for :full_width` — the projects list does, because it is the
  # "which body of work am I in" screen and sits outside the knowledge and
  # research navigation the sidebar offers. Kept as one predicate rather than a
  # controller-name check in the layout so the sidebar and the <main> column
  # width cannot disagree about which mode the page is in.
  def sidebar?
    user_signed_in? && !content_for?(:full_width)
  end

  # Standard text-token pricing as "$<in> in / $<out> out per Mtok",
  # or nil when the model carries no pricing at all.
  def model_pricing_label(model)
    standard = model.pricing&.dig("text_tokens", "standard") || {}
    input  = standard["input_per_million"]
    output = standard["output_per_million"]
    return nil if input.nil? && output.nil?

    fmt = ->(v) { v.nil? ? "?" : format("$%g", v.to_f) }
    "#{fmt.call(input)} in / #{fmt.call(output)} out per Mtok"
  end

  # Label used in model dropdowns: "<model_id> — $<in> in / $<out> out per Mtok".
  # Falls back to bare model_id when pricing is missing.
  def model_dropdown_label(model)
    pricing = model_pricing_label(model)
    pricing ? "#{model.model_id} — #{pricing}" : model.model_id
  end
end
