require 'cgi'

class Contacts::XlsxBuilder
  CONTENT_TYPE = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.freeze

  def initialize(rows:, sheet_name: 'Contacts')
    @rows = rows
    @sheet_name = sheet_name
  end

  def generate
    Contacts::ZipArchive.build(
      '[Content_Types].xml' => content_types,
      '_rels/.rels' => root_relationships,
      'xl/workbook.xml' => workbook,
      'xl/_rels/workbook.xml.rels' => workbook_relationships,
      'xl/worksheets/sheet1.xml' => worksheet,
      'xl/styles.xml' => styles
    )
  end

  private

  def content_types
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      </Types>
    XML
  end

  def root_relationships
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      </Relationships>
    XML
  end

  def workbook
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
          <sheet name="#{escape(@sheet_name)}" sheetId="1" r:id="rId1"/>
        </sheets>
      </workbook>
    XML
  end

  def workbook_relationships
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
      </Relationships>
    XML
  end

  def styles
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="1"><font><sz val="11"/><name val="Arial"/></font></fonts>
        <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
        <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
        <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
      </styleSheet>
    XML
  end

  def worksheet
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
          #{sheet_rows}
        </sheetData>
      </worksheet>
    XML
  end

  def sheet_rows
    @rows.each_with_index.map do |row, row_index|
      row_number = row_index + 1
      cells = row.each_with_index.map do |value, column_index|
        cell_reference = "#{column_name(column_index)}#{row_number}"
        %(<c r="#{cell_reference}" t="inlineStr"><is><t>#{escape(value)}</t></is></c>)
      end.join
      %(<row r="#{row_number}">#{cells}</row>)
    end.join
  end

  def column_name(index)
    name = +''
    current_index = index

    loop do
      name.prepend((65 + (current_index % 26)).chr)
      current_index = (current_index / 26) - 1
      break if current_index.negative?
    end

    name
  end

  def escape(value)
    CGI.escapeHTML(value.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '').gsub(/[[:cntrl:]]/, ''))
  end
end
