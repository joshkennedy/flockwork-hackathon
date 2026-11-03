class ProjectBannerVision
  PROMPT = <<~PROMPT.freeze
    You look at one photo for a church project's banner. Reply with only one JSON object, no prose:
    {"focus_x": number from 0 to 1, "focus_y": number from 0 to 1, "alt": "one short sentence describing the photo"}
    focus_x and focus_y are the main subject's position as fractions from the left and top edges. Use 0.5 and 0.5 when there is no clear subject.
    Describe only what is visible. Never name or guess who anyone is.
  PROMPT

  def self.call(blob) = new(blob).call

  def initialize(blob)
    @blob = blob
  end

  # Returns { focus_x:, focus_y:, alt: } or nil when no OpenRouter key is configured.
  def call
    return if ENV["OPENROUTER_API_KEY"].blank?

    file = downscaled_copy
    message = RubyLLM.chat(model: model, provider: :openrouter, assume_model_exists: true)
      .with_instructions(PROMPT)
      .with_max_output_tokens(300)
      .ask("Return the JSON for this photo.", with: file.path)
    parse(message.content)
  ensure
    file&.close!
  end

  private
    def model
      ENV.fetch("BANNER_LLM_MODEL", "anthropic/claude-haiku-5.5")
    end

    def downscaled_copy
      file = Tempfile.new([ "banner-vision", ".jpg" ])
      @blob.open do |source|
        ImageProcessing::Vips.source(source.path).resize_to_limit(1024, 1024).convert("jpg").saver(quality: 80).call(destination: file.path)
      end
      file
    end

    def parse(content)
      json = JSON.parse(content.to_s[/\{.*\}/m] || raise(ArgumentError, "Banner response had no JSON"))
      {
        focus_x: Float(json.fetch("focus_x")).clamp(0.0, 1.0),
        focus_y: Float(json.fetch("focus_y")).clamp(0.0, 1.0),
        alt: json["alt"].to_s.squish.truncate(200).presence
      }
    end
end
