require 'nokogiri'

class Contacts::XlsxParser
  def initialize(file_path)
    @file_path = file_path
  end

  def rows
    worksheet_rows.map do |row|
      row.xpath('./xmlns:c').map { |cell| cell_value(cell) }
    end
  end

  private

  def worksheet_rows
    worksheet.xpath('//xmlns:sheetData/xmlns:row')
  end

  def worksheet
    @worksheet ||= read_xml('xl/worksheets/sheet1.xml')
  end

  def shared_strings
    @shared_strings ||= begin
      document = read_xml('xl/sharedStrings.xml')
      document.xpath('//xmlns:si').map { |node| node.xpath('.//xmlns:t').map(&:text).join }
    rescue KeyError
      []
    end
  end

  def cell_value(cell)
    if cell['t'] == 's'
      shared_strings[cell.at_xpath('./xmlns:v')&.text.to_i].to_s
    elsif cell['t'] == 'inlineStr'
      cell.xpath('./xmlns:is/xmlns:t').map(&:text).join
    else
      cell.at_xpath('./xmlns:v')&.text.to_s
    end.strip
  end

  def read_xml(path)
    Nokogiri::XML(Contacts::ZipArchive.read(@file_path, path))
  end
end
