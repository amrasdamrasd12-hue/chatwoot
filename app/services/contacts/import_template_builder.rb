class Contacts::ImportTemplateBuilder
  CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
  DEFAULT_COLUMNS = %w[name phone_1 classification governorate district].freeze
  AVAILABLE_COLUMNS = %w[name email identifier classification
                         phone_1 phone_2 phone_3
                         governorate district neighborhood street].freeze
  SAMPLE_VALUES = {
    'name' => 'Ahmed Mohamed',
    'email' => 'ahmed@example.com',
    'identifier' => 'customer-123',
    'classification' => 'Regular',
    'phone_1' => '+201001234567',
    'phone_2' => '+201009876543',
    'phone_3' => '',
    'governorate' => 'القاهرة',
    'district' => 'مصر الجديدة',
    'neighborhood' => 'الميرغني',
    'street' => 'شارع النيل'
  }.freeze

  def self.valid_columns(column_names, account: nil)
    columns = Array(column_names).presence || DEFAULT_COLUMNS
    selected_columns = columns & available_columns(account)
    selected_columns.presence || DEFAULT_COLUMNS
  end

  def self.available_columns(account)
    return AVAILABLE_COLUMNS unless account

    AVAILABLE_COLUMNS + account.custom_attribute_definitions.with_attribute_model('contact_attribute').pluck(:attribute_key)
  end

  def initialize(column_names, account: nil)
    @account = account
    @columns = self.class.valid_columns(column_names, account: account)
  end

  def generate
    Contacts::XlsxBuilder.new(rows: [@columns, sample_row]).generate
  end

  private

  def sample_row
    @columns.map { |column| SAMPLE_VALUES[column] || custom_attribute_sample_value(column) }
  end

  def custom_attribute_sample_value(column)
    custom_attribute = custom_attribute_definitions[column]
    custom_attribute&.default_value.presence || custom_attribute&.attribute_display_name.presence || ''
  end

  def custom_attribute_definitions
    @custom_attribute_definitions ||= @account
                                      &.custom_attribute_definitions
                                      &.with_attribute_model('contact_attribute')
                                      &.index_by(&:attribute_key) || {}
  end
end
