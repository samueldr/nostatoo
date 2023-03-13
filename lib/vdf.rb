# frozen_string_literal: true

# VDF parsing and rendering
module VDF
  USE_DEBUG_DATA = false

  # Used as a convenient buffer length for byteslice-ing
  TOKEN_MAX_LENGTH = 1024 # As documented
  # > Each token can be up to 1024 characters long
  #  — https://developer.valvesoftware.com/wiki/KeyValues

  TYPES = {
    0x00 => :Map,
    0x01 => :String,
    0x02 => :Integer,
    # NOTE: Other types apparently exist, but have not been needed yet.
    0x08 => :EndOfMap,
  }.freeze

  def self.parse(contents)
    entry = parse_map_entry(contents, 0).first
    [[entry[:name], entry[:value]]].to_h
  end

  def self.parse_map_entry(data, pos)
    entry = {}

    # We're pre-rendering as hex `0x__` since it's used for convenient debugging.
    entry[:pos] = "0x#{entry_pos.to_s(16)}" if USE_DEBUG_DATA

    # A map entry is always at least a type (one byte long)
    raw_type = data.byteslice(pos).ord
    type = TYPES[raw_type]
    entry[:type] = type
    pos += 1

    # This type signals the map is done.
    return nil if type == :EndOfMap

    # Next to the type is the name of the entry, as a null-terminated string.
    name = data.byteslice(pos, TOKEN_MAX_LENGTH).unpack1("Z*")
    entry[:name] = name
    pos += name.bytesize + 1

    # Finally, next to the string is the actual value.
    # The actual value depends on the type.
    entry[:value] =
      case type
      when :Map
        values = []
        while (value, new_pos = parse_map_entry(data, pos))
          pos = new_pos
          values << value
        end
        pos += 1 # (Account for the :EndOfMap byte)
        values.to_h { |v| [v[:name], v[:value]] }
      when :String # Null-terminated
        value = data.byteslice(pos, TOKEN_MAX_LENGTH).unpack1("Z*")
        pos += value.bytesize + 1
        value
      when :Integer # 32 bit
        value = data.byteslice(pos, 4).unpack1("L<")
        pos += (32 / 8)
        value

      when nil
        raise "UNEXPECTED TYPE 0x#{raw_type.to_s(16)}"
      else
        raise "UNHANDLED TYPE :#{type} (0x#{raw_type.to_s(16)})"
      end

    if USE_DEBUG_DATA
      case type
      when :Map
        entry[:length] = entry[:value].length
      when :String
        entry[:bytesize] = value.bytesize
        entry[:length] = value.length
      end
    end

    [entry, pos]
  end
end