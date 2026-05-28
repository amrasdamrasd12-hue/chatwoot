class Contacts::ExportBuilder
  CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
  DEFAULT_COLUMNS = %w[id name email phone_number].freeze
  ADDITIONAL_ATTRIBUTE_COLUMNS = %w[classification phone_1 phone_2 phone_3 governorate district neighborhood street].freeze

  def initialize(account:, user:, column_names:, params:)
    @account = account
    @user = user
    @column_names = column_names
    @params = params || {}
  end

  def generate
    columns = export_columns
    rows = [columns.pluck(:header)] + contacts.map do |contact|
      columns.map { |column| column[:value].call(contact) }
    end
    Contacts::XlsxBuilder.new(rows: rows).generate
  end

  def filename
    "#{@account.name}_#{@account.id}_contacts.xlsx"
  end

  private

  def contacts
    params = normalized_filter_params
    return resolved_contacts.where(id: params[:selected_ids]) if params[:selected_ids].present?

    if params.present? && params[:payload].present? && params[:payload].any?
      result = ::Contacts::FilterService.new(@account, @user, params).perform
      result[:contacts]
    elsif params[:label].present?
      resolved_contacts.tagged_with(params[:label], any: true)
    else
      resolved_contacts
    end
  end

  def resolved_contacts
    @account.contacts.resolved_contacts(use_crm_v2: @account.feature_enabled?('crm_v2'))
  end

  def export_columns
    selected_columns.filter_map do |column|
      if column.start_with?('custom_attribute:')
        custom_attribute_column(column.delete_prefix('custom_attribute:'))
      elsif ADDITIONAL_ATTRIBUTE_COLUMNS.include?(column)
        { header: column, value: additional_attribute_extractor(column) }
      elsif Contact.column_names.include?(column)
        { header: column, value: ->(contact) { contact.public_send(column) } }
      end
    end
  end

  def additional_attribute_extractor(column)
    case column
    when 'classification'
      ->(c) { c.additional_attributes&.[]('custom_customer_classification').to_s }
    when 'phone_1', 'phone_2', 'phone_3'
      idx = column[-1].to_i - 1
      ->(c) { (c.additional_attributes&.[]('custom_customer_mobile_numbers') || [])[idx]&.[]('phone').to_s }
    when 'governorate', 'district', 'neighborhood', 'street'
      ->(c) { c.additional_attributes&.dig('custom_addresses', 0, column).to_s }
    end
  end

  def selected_columns
    Array(@column_names).presence || DEFAULT_COLUMNS
  end

  def custom_attribute_column(attribute_key)
    custom_attribute = custom_attribute_definitions[attribute_key]
    return unless custom_attribute

    {
      header: custom_attribute.attribute_display_name.presence || attribute_key,
      value: ->(contact) { contact.custom_attributes[attribute_key].to_s }
    }
  end

  def custom_attribute_definitions
    @custom_attribute_definitions ||=
      @account.custom_attribute_definitions
              .with_attribute_model('contact_attribute')
              .index_by(&:attribute_key)
  end

  def normalized_filter_params
    params = @params.deep_dup.with_indifferent_access
    payload = params[:payload]
    return params unless payload.is_a?(Array) && payload.last.present?

    payload.last[:query_operator] = nil
    params
  end
end
