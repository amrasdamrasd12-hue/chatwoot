class Contacts::Importer
  def initialize(account:, file:)
    @account = account
    @file = file
    @contact_manager = DataImport::ContactManager.new(account)
  end

  def perform
    contacts, rejected_contacts = parse_excel_and_build_contacts
    Contact.import(contacts, synchronize: contacts, on_duplicate_key_ignore: true, track_validation_failures: true, validate: true, batch_size: 1000)

    {
      processed_records: contacts.length,
      rejected_records: rejected_contacts.length,
      total_records: contacts.length + rejected_contacts.length
    }
  end

  private

  def parse_excel_and_build_contacts
    contacts = []
    rejected_contacts = []

    xlsx_rows.each do |row|
      current_contact = @contact_manager.build_contact(row.with_indifferent_access)
      if current_contact.valid?
        contacts << current_contact
      else
        rejected_contacts << row
      end
    end

    [contacts, rejected_contacts]
  end

  def xlsx_rows
    workbook_rows = Contacts::XlsxParser.new(@file.path).rows
    return [] if workbook_rows.length < 2

    headers = workbook_headers(workbook_rows)
    workbook_rows.drop(1).filter_map do |row_values|
      values = row_values.map { |value| normalize_cell_value(value) }
      row = headers.zip(values).to_h
      row if row.values.any?(&:present?)
    end
  end

  def workbook_headers(workbook_rows)
    workbook_rows.first.map { |header| normalize_cell_value(header) }
  end

  def normalize_cell_value(value)
    return '' if value.nil?

    value.to_s.strip
  end
end
