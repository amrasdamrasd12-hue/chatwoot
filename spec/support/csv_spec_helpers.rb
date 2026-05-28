module CsvSpecHelpers
  EXCEL_CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  # Generates a Rack::Test::UploadedFile object from an array of arrays
  # data: Accepts an array of arrays as the only argument
  def generate_csv_file(data)
    # Create a temporary file
    temp_file = Tempfile.new(['data', '.csv'])

    # Write the array of arrays to the temporary file as CSV
    CSV.open(temp_file.path, 'wb') do |csv|
      data.each do |row|
        csv << row
      end
    end

    # Create and return a Rack::Test::UploadedFile object
    Rack::Test::UploadedFile.new(temp_file.path, 'text/csv')
  end

  def generate_xlsx_file(data)
    temp_file = Tempfile.new(['data', '.xlsx'])
    temp_file.binmode
    temp_file.write(generate_xlsx_data(data))
    temp_file.rewind

    Rack::Test::UploadedFile.new(temp_file.path, EXCEL_CONTENT_TYPE)
  end

  def generate_xlsx_data(data)
    Contacts::XlsxBuilder.new(rows: data).generate
  end

  def xlsx_rows(workbook_data)
    temp_file = Tempfile.new(['data', '.xlsx'])
    temp_file.binmode
    temp_file.write(workbook_data)
    temp_file.rewind

    workbook_rows = Contacts::XlsxParser.new(temp_file.path).rows
    headers = workbook_rows.first.map(&:to_s)
    return [] if workbook_rows.length < 2

    workbook_rows.drop(1).map do |row|
      values = row.map { |value| value.nil? ? '' : value.to_s }
      headers.zip(values).to_h
    end
  ensure
    temp_file&.close
    temp_file&.unlink
  end
end
