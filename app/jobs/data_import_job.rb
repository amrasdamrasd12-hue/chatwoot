# TODO: logic is written tailored to contact import since its the only import available
# let's break this logic and clean this up in future

class DataImportJob < ApplicationJob
  queue_as :low
  retry_on ActiveStorage::FileNotFoundError, wait: 1.minute, attempts: 3

  def perform(data_import)
    @data_import = data_import
    @contact_manager = DataImport::ContactManager.new(@data_import.account)
    begin
      process_import_file
      send_import_notification_to_admin
    rescue KeyError, Zlib::Error => e
      handle_excel_error(e)
    end
  end

  private

  def process_import_file
    @data_import.update!(status: :processing)
    contacts, rejected_contacts = parse_excel_and_build_contacts

    import_contacts(contacts)
    update_data_import_status(contacts.length, rejected_contacts.length)
    save_failed_records_xlsx(rejected_contacts)
  end

  def parse_excel_and_build_contacts
    contacts = []
    rejected_contacts = []

    with_import_file do |file|
      xlsx_rows(file).each do |row|
        current_contact = @contact_manager.build_contact(row.with_indifferent_access)
        if current_contact.valid?
          contacts << current_contact
        else
          append_rejected_contact(row, current_contact, rejected_contacts)
        end
      end
    end

    [contacts, rejected_contacts]
  end

  def append_rejected_contact(row, contact, rejected_contacts)
    row = row.to_h
    row['errors'] = contact.errors.full_messages.join(', ')
    rejected_contacts << row
  end

  def import_contacts(contacts)
    # <struct ActiveRecord::Import::Result failed_instances=[], num_inserts=1, ids=[444, 445], results=[]>
    Contact.import(contacts, synchronize: contacts, on_duplicate_key_ignore: true, track_validation_failures: true, validate: true, batch_size: 1000)
  end

  def update_data_import_status(processed_records, rejected_records)
    @data_import.update!(status: :completed, processed_records: processed_records, total_records: processed_records + rejected_records)
  end

  def save_failed_records_xlsx(rejected_contacts)
    workbook_data = generate_xlsx_data(rejected_contacts)
    return if workbook_data.blank?

    @data_import.failed_records.attach(
      io: StringIO.new(workbook_data),
      filename: "#{Time.zone.today.strftime('%Y%m%d')}_contacts.xlsx",
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
  end

  def generate_xlsx_data(rejected_contacts)
    return if rejected_contacts.blank?

    headers = excel_headers + ['errors']
    rows = [headers] + rejected_contacts.map { |record| headers.map { |header| record[header] } }
    Contacts::XlsxBuilder.new(rows: rows, sheet_name: 'Failed contacts').generate
  end

  def handle_excel_error(error)
    Rails.logger.error("Contact import failed for account #{@data_import.account_id}: #{error.message}")
    @data_import.update!(status: :failed)
    send_import_failed_notification_to_admin
  end

  def send_import_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_complete(@data_import).deliver_later
  end

  def send_import_failed_notification_to_admin
    AdministratorNotifications::AccountNotificationMailer.with(account: @data_import.account).contact_import_failed.deliver_later
  end

  def excel_headers
    headers = []
    with_import_file do |file|
      headers = workbook_headers(Contacts::XlsxParser.new(file.path).rows)
    end
    headers
  end

  def xlsx_rows(file)
    workbook_rows = Contacts::XlsxParser.new(file.path).rows
    return [] if workbook_rows.length < 2

    headers = workbook_headers(workbook_rows)
    workbook_rows.drop(1).filter_map do |row_values|
      values = row_values.map { |value| normalize_cell_value(value) }
      row = headers.zip(values).to_h
      row if row.values.any?(&:present?)
    end
  end

  def workbook_headers(workbook_rows)
    return [] if workbook_rows.blank?

    workbook_rows.first.map { |header| normalize_cell_value(header) }
  end

  def normalize_cell_value(value)
    return '' if value.nil?

    value.to_s.strip
  end

  def with_import_file
    temp_dir = Rails.root.join('tmp/imports')
    FileUtils.mkdir_p(temp_dir)

    @data_import.import_file.open(tmpdir: temp_dir) do |file|
      file.binmode
      yield file
    end
  end
end
