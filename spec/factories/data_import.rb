FactoryBot.define do
  factory :data_import do
    data_type { 'contacts' }
    import_file do
      headers = %w[id first_name last_name email gender ip_address identifier phone_number company]
      row = ['1', 'Clarice', 'Uzzell', 'cuzzell0@mozilla.org', 'Genderfluid', '70.61.11.201',
             'bb4e11cd-0f23-49da-a123-dcc1fec6852c', '918080808080', 'My Company Name']

      temp_file = Tempfile.new(['contacts', '.xlsx'])
      temp_file.binmode
      temp_file.write(Contacts::XlsxBuilder.new(rows: [headers, row]).generate)
      temp_file.rewind
      Rack::Test::UploadedFile.new(temp_file.path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end
    account
  end
end
