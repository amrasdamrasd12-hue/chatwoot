# Eltafouk: per-account configuration for the pre-send spell-check guard
# (Captain::SpellCheckService). Stored on Account#settings JSONB so it
# rides along with the other Captain-adjacent settings. The CommentThread
# panel (separate React app at /app/) reads the same settings via this
# endpoint so the two UIs stay in lockstep.
class Api::V1::Accounts::SpellCheckSettingsController < Api::V1::Accounts::BaseController
  before_action :check_authorization

  DEFAULTS = {
    'dm_enabled' => true,
    'comments_enabled' => false,
    'strictness' => Captain::SpellCheckService::DEFAULT_STRICTNESS,
    'long_message_strategy' => Captain::SpellCheckService::DEFAULT_STRATEGY
  }.freeze

  def show
    render json: serialized_response(current_settings)
  end

  def update
    merged = current_settings.merge(filtered_params)
    Current.account.spell_check_settings = merged
    Current.account.save!
    render json: serialized_response(merged)
  end

  private

  def serialized_response(settings)
    {
      settings: settings,
      strictness_labels: Captain::SpellCheckService::STRICTNESS_LABELS,
      long_message_threshold: Captain::SpellCheckService::LONG_MESSAGE_THRESHOLD
    }
  end

  def current_settings
    DEFAULTS.merge(Current.account.spell_check_settings.to_h.stringify_keys)
  end

  def filtered_params
    permitted = params.require(:settings)
                      .permit(:dm_enabled, :comments_enabled, :strictness, :long_message_strategy)
                      .to_h.stringify_keys
    permitted['strictness'] = permitted['strictness'].to_i if permitted.key?('strictness')
    if permitted.key?('strictness') && !permitted['strictness'].between?(1, 6)
      permitted['strictness'] = Captain::SpellCheckService::DEFAULT_STRICTNESS
    end
    if permitted.key?('long_message_strategy') &&
       Captain::SpellCheckService::VALID_STRATEGIES.exclude?(permitted['long_message_strategy'])
      permitted['long_message_strategy'] = Captain::SpellCheckService::DEFAULT_STRATEGY
    end
    %w[dm_enabled comments_enabled].each do |bool_key|
      permitted[bool_key] = ActiveModel::Type::Boolean.new.cast(permitted[bool_key]) if permitted.key?(bool_key)
    end
    permitted
  end

  def check_authorization
    authorize(Account, :update?)
  end
end
