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
end
