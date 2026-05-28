require 'zlib'

class Contacts::ZipArchive
  LOCAL_FILE_HEADER = 0x04034b50
  CENTRAL_DIRECTORY_HEADER = 0x02014b50
  END_OF_CENTRAL_DIRECTORY = 0x06054b50
  COMPRESSION_STORE = 0
  COMPRESSION_DEFLATE = 8

  def self.build(entries)
    new(entries: entries).build
  end

  def self.read(file_path, entry_name)
    new(file_path: file_path).read(entry_name)
  end

  def initialize(entries: nil, file_path: nil)
    @entries = entries
    @file_path = file_path
  end

  def build
    output = ''.b
    central_directory = ''.b

    @entries.each do |path, content|
      local_header_offset = output.bytesize
      compressed_content = deflate(content)
      crc = Zlib.crc32(content)

      output << local_header(path, content, compressed_content, crc)
      output << compressed_content
      central_directory << central_directory_header(path, content, compressed_content, crc, local_header_offset)
    end

    output << central_directory
    output << end_of_central_directory(@entries.length, central_directory.bytesize, output.bytesize - central_directory.bytesize)
    output
  end

  def read(entry_name)
    entry = central_directory_entries.find { |current_entry| current_entry[:name] == entry_name }
    raise KeyError, entry_name if entry.blank?

    data = File.binread(@file_path)
    local_header = data.byteslice(entry[:offset], 30)
    fields = local_header.unpack('VvvvvvVVVvv')
    file_name_length = fields[9]
    extra_length = fields[10]
    data_offset = entry[:offset] + 30 + file_name_length + extra_length
    compressed_content = data.byteslice(data_offset, entry[:compressed_size])

    return compressed_content if entry[:compression_method] == COMPRESSION_STORE

    inflate(compressed_content)
  end

  private

  def local_header(path, content, compressed_content, crc)
    [
      LOCAL_FILE_HEADER, 20, 0, COMPRESSION_DEFLATE, 0, 0, crc,
      compressed_content.bytesize, content.bytesize, path.bytesize, 0
    ].pack('VvvvvvVVVvv') + path
  end

  def central_directory_header(path, content, compressed_content, crc, local_header_offset)
    [
      CENTRAL_DIRECTORY_HEADER, 20, 20, 0, COMPRESSION_DEFLATE, 0, 0, crc,
      compressed_content.bytesize, content.bytesize, path.bytesize, 0, 0, 0, 0, 0,
      local_header_offset
    ].pack('VvvvvvvVVVvvvvvVV') + path
  end

  def end_of_central_directory(entry_count, central_directory_size, central_directory_offset)
    [
      END_OF_CENTRAL_DIRECTORY, 0, 0, entry_count, entry_count,
      central_directory_size, central_directory_offset, 0
    ].pack('VvvvvVVv')
  end

  def central_directory_entries
    data = File.binread(@file_path)
    entry_count, offset = central_directory_location(data)

    Array.new(entry_count) do
      entry, offset = central_directory_entry(data, offset)
      entry
    end
  end

  def central_directory_location(data)
    eocd_offset = data.rindex([END_OF_CENTRAL_DIRECTORY].pack('V'))
    raise KeyError, 'end of central directory' if eocd_offset.blank?

    eocd = data.byteslice(eocd_offset, 22).unpack('VvvvvVVv')
    [eocd[4], eocd[6]]
  end

  def central_directory_entry(data, offset)
    fields = data.byteslice(offset, 46).unpack('VvvvvvvVVVvvvvvVV')
    name_length = fields[10]
    extra_length = fields[11]
    comment_length = fields[12]
    name = data.byteslice(offset + 46, name_length)
    next_offset = offset + 46 + name_length + extra_length + comment_length

    [
      {
        name: name,
        compression_method: fields[4],
        compressed_size: fields[8],
        offset: fields[16]
      },
      next_offset
    ]
  end

  def deflate(content)
    deflater = Zlib::Deflate.new(Zlib::BEST_SPEED, -Zlib::MAX_WBITS)
    deflater.deflate(content, Zlib::FINISH)
  ensure
    deflater&.close
  end

  def inflate(content)
    inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    inflater.inflate(content)
  ensure
    inflater&.close
  end
end
