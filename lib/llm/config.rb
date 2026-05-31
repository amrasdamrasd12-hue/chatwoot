require 'ruby_llm'

module Llm::Config
  DEFAULT_MODEL = 'gpt-4.1-mini'.freeze
  # Eltafouk: when the install runs Captain on Google Vertex AI, every task
  # uses this Gemini model (covered by the Google AI Ultra $100/mo Cloud
  # credit). OpenAI stays as a fallback — flip CAPTAIN_LLM_PROVIDER to
  # 'openai' to switch back instantly.
  VERTEX_MODEL = 'gemini-2.5-flash'.freeze

  class << self
    def initialized?
      @initialized ||= false
    end

    # Active LLM provider: 'vertex' or 'openai'. Defaults to vertex when
    # it's configured (project id present), else openai. An explicit
    # CAPTAIN_LLM_PROVIDER override wins.
    def provider
      override = InstallationConfig.find_by(name: 'CAPTAIN_LLM_PROVIDER')&.value.presence
      override || (vertex_configured? ? 'vertex' : 'openai')
    end

    def vertex?
      provider == 'vertex' && vertex_configured?
    end

    def vertex_configured?
      vertex_project_id.present?
    end

    def vertex_project_id
      InstallationConfig.find_by(name: 'CAPTAIN_VERTEX_PROJECT_ID')&.value.presence
    end

    def vertex_location
      InstallationConfig.find_by(name: 'CAPTAIN_VERTEX_LOCATION')&.value.presence || 'us-central1'
    end

    # Vertex AI auth comes from GOOGLE_APPLICATION_CREDENTIALS (service
    # account JSON on the server) via RubyLLM's vertexai provider.
    def with_vertex
      context = RubyLLM.context do |config|
        config.vertexai_project_id = vertex_project_id
        config.vertexai_location = vertex_location
      end

      yield context
    end

    def initialize!
      return if @initialized

      configure_ruby_llm
      @initialized = true
    end

    def reset!
      @initialized = false
    end

    def with_api_key(api_key, api_base: nil)
      context = RubyLLM.context do |config|
        config.openai_api_key = api_key
        config.openai_api_base = api_base
      end

      yield context
    end

    private

    def configure_ruby_llm
      RubyLLM.configure do |config|
        config.openai_api_key = system_api_key if system_api_key.present?
        config.openai_api_base = openai_endpoint.chomp('/') if openai_endpoint.present?
        config.logger = Rails.logger
      end
    end

    def system_api_key
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_API_KEY')&.value
    end

    def openai_endpoint
      InstallationConfig.find_by(name: 'CAPTAIN_OPEN_AI_ENDPOINT')&.value
    end
  end
end
