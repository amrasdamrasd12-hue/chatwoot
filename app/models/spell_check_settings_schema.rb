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
      'strictness': { 'type': %w[integer null], 'minimum': 1, 'maximum': 6 },
      'long_message_strategy': {
        'type': %w[string null],
        'enum': %w[skip nano mini hybrid]
      },
      'evaluation_mode': { 'type': %w[boolean null] },
      'evaluation_strictness': { 'type': %w[integer null], 'minimum': 1, 'maximum': 6 }
    },
    'additionalProperties': false
  }.freeze
end
