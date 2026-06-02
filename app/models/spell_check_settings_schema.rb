# Eltafouk: JSON-schema fragment for
# Account#settings['spell_check_settings'], lifted out of the inline
# Account::SETTINGS_PARAMS_SCHEMA literal to keep that god-object model
# under its line budget. Referenced by full path from [[Account]] so it
# autoloads before the schema constant is built. The shape here must stay
# byte-identical to what it replaced — JsonSchemaValidator enforces it.
module SpellCheckSettingsSchema
  FRAGMENT = {
    'type': %w[object null],
    'properties': {
      'dm_enabled': { 'type': %w[boolean null] },
      'comments_enabled': { 'type': %w[boolean null] },
      'long_message_strategy': {
        'type': %w[string null],
        'enum': %w[skip nano mini hybrid]
      }
    },
    'additionalProperties': false
  }.freeze
end
