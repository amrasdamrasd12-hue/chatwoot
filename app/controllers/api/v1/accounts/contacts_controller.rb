class Api::V1::Accounts::ContactsController < Api::V1::Accounts::BaseController # rubocop:disable Metrics/ClassLength
  include Sift
  sort_on :email, type: :string
  sort_on :name, internal_name: :order_on_name, type: :scope, scope_params: [:direction]
  sort_on :phone_number, type: :string
  sort_on :last_activity_at, internal_name: :order_on_last_activity_at, type: :scope, scope_params: [:direction]
  sort_on :created_at, internal_name: :order_on_created_at, type: :scope, scope_params: [:direction]
  sort_on :updated_at, internal_name: :order_on_updated_at, type: :scope, scope_params: [:direction]
  sort_on :company, internal_name: :order_on_company_name, type: :scope, scope_params: [:direction]
  sort_on :city, internal_name: :order_on_city, type: :scope, scope_params: [:direction]
  sort_on :country, internal_name: :order_on_country_name, type: :scope, scope_params: [:direction]

  DEFAULT_RESULTS_PER_PAGE = 15
  MAX_RESULTS_PER_PAGE = 1000
  EXCEL_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze
  EXCEL_MIME_TYPES = [EXCEL_CONTENT_TYPE, 'application/octet-stream'].freeze

  before_action :check_authorization
  before_action :set_current_page, only: [:index, :active, :search, :filter]
  before_action :set_contacts_stats, only: [:index, :active, :search, :filter]
  before_action :fetch_contact, only: [:show, :update, :destroy, :avatar, :contactable_inboxes, :destroy_custom_attributes]
  before_action :set_include_contact_inboxes, only: [:index, :active, :search, :filter, :show, :update]

  def index
    @contacts = fetch_contacts(resolved_contacts)
    @contacts_count = @contacts.total_count
  end

  def search
    render json: { error: 'Specify search string with parameter q' }, status: :unprocessable_entity if params[:q].blank? && return

    search_term = "%#{params[:q].strip}%"
    contacts = Current.account.contacts.where(
      "name ILIKE :search
       OR email ILIKE :search
       OR phone_number ILIKE :search
       OR contacts.identifier LIKE :search
       OR EXISTS (
         SELECT 1 FROM jsonb_array_elements(
           COALESCE(contacts.additional_attributes->'custom_customer_mobile_numbers', '[]'::jsonb)
         ) AS mob
         WHERE mob->>'phone' ILIKE :search
       )",
      search: search_term
    )
    @contacts = fetch_contacts_with_has_more(contacts)
  end

  def import
    render json: { error: I18n.t('errors.contacts.import.failed') }, status: :unprocessable_entity and return if params[:import_file].blank?
    unless xlsx_file?(params[:import_file])
      render json: { error: I18n.t('errors.contacts.import.invalid_file_type') }, status: :unprocessable_entity and return
    end

    result = Contacts::Importer.new(account: Current.account, file: params[:import_file]).perform
    render json: { message: I18n.t('errors.contacts.import.success'), payload: result }
  rescue KeyError, Zlib::Error
    render json: { error: I18n.t('errors.contacts.import.invalid_file_type') }, status: :unprocessable_entity
  end

  def export
    column_names = params['column_names']
    filter_params = {
      :payload => params.permit!['payload'],
      :label => params.permit!['label'],
      :selected_ids => selected_contact_ids
    }
    export = Contacts::ExportBuilder.new(account: Current.account, user: Current.user, column_names: column_names, params: filter_params)

    send_data export.generate,
              filename: export.filename,
              type: EXCEL_CONTENT_TYPE,
              disposition: 'attachment'
  end

  def import_template
    columns = Contacts::ImportTemplateBuilder.valid_columns(params[:column_names], account: Current.account)
    workbook_data = Contacts::ImportTemplateBuilder.new(columns, account: Current.account).generate

    send_data workbook_data,
              filename: 'contacts_import_template.xlsx',
              type: EXCEL_CONTENT_TYPE,
              disposition: 'attachment'
  end

  def preview_import
    render_import_file_missing and return if params[:import_file].blank?
    render_invalid_import_file and return unless xlsx_file?(params[:import_file])

    render json: { payload: import_preview_payload }
  rescue KeyError, Zlib::Error
    render_invalid_import_file
  end

  # returns online contacts
  def active
    contacts = Current.account.contacts.where(id: ::OnlineStatusTracker
                  .get_available_contact_ids(Current.account.id))
    @contacts = fetch_contacts(contacts)
    @contacts_count = @contacts.total_count
  end

  def show; end

  def filter
    result = ::Contacts::FilterService.new(Current.account, Current.user, params.permit!).perform
    contacts = result[:contacts]
    @contacts_count = result[:count]
    @contacts = fetch_contacts(contacts)
  rescue CustomExceptions::CustomFilter::InvalidAttribute,
         CustomExceptions::CustomFilter::InvalidOperator,
         CustomExceptions::CustomFilter::InvalidQueryOperator,
         CustomExceptions::CustomFilter::InvalidValue => e
    render_could_not_create_error(e.message)
  end

  def contactable_inboxes
    @all_contactable_inboxes = Contacts::ContactableInboxesService.new(contact: @contact).get
    @contactable_inboxes = @all_contactable_inboxes.select { |contactable_inbox| policy(contactable_inbox[:inbox]).show? }
  end

  # TODO : refactor this method into dedicated contacts/custom_attributes controller class and routes
  def destroy_custom_attributes
    @contact.custom_attributes = @contact.custom_attributes.excluding(params[:custom_attributes])
    @contact.save!
  end

  def create
    ActiveRecord::Base.transaction do
      @contact = Current.account.contacts.new(permitted_params.except(:avatar_url))
      @contact.save!
      @contact_inbox = build_contact_inbox
      process_avatar_from_url
    end
  rescue ActiveRecord::RecordInvalid => e
    phone_error = e.record.errors.where(:base, :taken_by).first
    raise unless phone_error

    render json: { message: phone_error.message, attributes: ['base'], error_type: 'phone_duplicate' },
           status: :unprocessable_entity
  end

  def update
    @contact.assign_attributes(contact_update_params)
    @contact.save!
    process_avatar_from_url
  rescue ActiveRecord::RecordInvalid => e
    phone_error = e.record.errors.where(:base, :taken_by).first
    raise unless phone_error

    render json: { message: phone_error.message, attributes: ['base'], error_type: 'phone_duplicate' },
           status: :unprocessable_entity
  end

  def destroy
    if ::OnlineStatusTracker.get_presence(
      @contact.account.id, 'Contact', @contact.id
    )
      return render_error({ message: I18n.t('contacts.online.delete', contact_name: @contact.name.capitalize) },
                          :unprocessable_entity)
    end

    @contact.destroy!
    head :ok
  end

  def avatar
    @contact.avatar.purge if @contact.avatar.attached?
    @contact
  end

  private

  def render_import_file_missing
    render json: { error: I18n.t('errors.contacts.import.failed') }, status: :unprocessable_entity
  end

  def render_invalid_import_file
    render json: { error: I18n.t('errors.contacts.import.invalid_file_type') }, status: :unprocessable_entity
  end

  def import_preview_payload
    rows = Contacts::XlsxParser.new(params[:import_file].path).rows
    headers = rows.first || []

    {
      headers: headers,
      rows: rows.drop(1).first(3).map { |row| headers.each_index.map { |index| row[index].to_s } }
    }
  end

  def selected_contact_ids
    Array(params[:selected_ids]).filter_map do |id|
      next if id.blank?

      contact_id = id.to_i
      contact_id if contact_id.positive?
    end
  end

  def xlsx_file?(file)
    File.extname(file.original_filename.to_s).casecmp('.xlsx').zero? &&
      EXCEL_MIME_TYPES.include?(file.content_type)
  end

  # TODO: Move this to a finder class
  def resolved_contacts
    return @resolved_contacts if @resolved_contacts

    @resolved_contacts = Current.account.contacts.resolved_contacts(use_crm_v2: Current.account.feature_enabled?('crm_v2'))

    @resolved_contacts = @resolved_contacts.tagged_with(params[:labels], any: true) if params[:labels].present?
    @resolved_contacts
  end

  def set_current_page
    @current_page = params[:page] || 1
  end

  def set_contacts_stats
    total_contacts = Current.account.contacts.count
    classification_counts = Current.account.contacts
                                   .where("additional_attributes->>'custom_customer_classification' IS NOT NULL")
                                   .where("additional_attributes->>'custom_customer_classification' != ''")
                                   .group("additional_attributes->>'custom_customer_classification'")
                                   .count

    @contacts_stats = {
      total_count: total_contacts,
      new_this_week_count: Current.account.contacts.where('created_at >= ?', 1.week.ago).count,
      classification_counts: classification_counts
    }
  end

  def results_per_page
    requested = params[:per_page].to_i
    return DEFAULT_RESULTS_PER_PAGE unless requested.positive?

    [requested, MAX_RESULTS_PER_PAGE].min
  end

  def fetch_contacts(contacts)
    # Build includes hash to avoid separate query when contact_inboxes are needed
    includes_hash = { avatar_attachment: [:blob] }
    includes_hash[:contact_inboxes] = { inbox: :channel } if @include_contact_inboxes

    filtrate(contacts)
      .includes(includes_hash)
      .page(@current_page)
      .per(results_per_page)
  end

  def fetch_contacts_with_has_more(contacts)
    includes_hash = { avatar_attachment: [:blob] }
    includes_hash[:contact_inboxes] = { inbox: :channel } if @include_contact_inboxes

    per_page = results_per_page
    offset = (@current_page.to_i - 1) * per_page
    results = filtrate(contacts)
              .includes(includes_hash)
              .offset(offset)
              .limit(per_page + 1)
              .to_a

    @has_more = results.size > per_page
    results = results.first(per_page) if @has_more
    @contacts_count = results.size
    results
  end

  def build_contact_inbox
    return if params[:inbox_id].blank?

    inbox = Current.account.inboxes.find(params[:inbox_id])
    ContactInboxBuilder.new(
      contact: @contact,
      inbox: inbox,
      source_id: params[:source_id]
    ).perform
  end

  def permitted_params
    params.permit(:name, :identifier, :email, :phone_number, :avatar, :blocked, :avatar_url, additional_attributes: {}, custom_attributes: {})
  end

  def contact_custom_attributes
    return @contact.custom_attributes.merge(permitted_params[:custom_attributes].to_unsafe_h) if permitted_params[:custom_attributes]

    @contact.custom_attributes
  end

  def contact_additional_attributes
    return @contact.additional_attributes.merge(params[:additional_attributes].to_unsafe_h) if params[:additional_attributes].present?

    @contact.additional_attributes
  end

  def contact_update_params
    permitted_params.except(:custom_attributes, :avatar_url)
                    .merge({ custom_attributes: contact_custom_attributes })
                    .merge({ additional_attributes: contact_additional_attributes })
  end

  def set_include_contact_inboxes
    @include_contact_inboxes = if params[:include_contact_inboxes].present?
                                 params[:include_contact_inboxes] == 'true'
                               else
                                 true
                               end
  end

  def fetch_contact
    @contact = Current.account.contacts.includes(contact_inboxes: [:inbox]).find(params[:id])
  end

  def process_avatar_from_url
    ::Avatar::AvatarFromUrlJob.perform_later(@contact, params[:avatar_url]) if params[:avatar_url].present?
  end

  def render_error(error, error_status)
    render json: error, status: error_status
  end
end
