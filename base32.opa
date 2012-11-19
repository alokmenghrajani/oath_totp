/**
 * An incomplete base32 library for Opa.
 *
 * This library only encodes binary data to base32.
 *
 * Someone still needs to write the decoding part :)
 */
module Base32 {
  function string encode(binary data) {
    len = Binary.length(data)

    copy = Binary.get_binary(data, 0, len)

    // pad if the length is not a multiple of 5
    pad = mod(5 - mod(len, 5), 5)

    Binary.add_fill(copy, pad, 0)

    // process the data, 5 bytes at a time
    encoded = encode_rec(copy, 0, len+pad, "")
    encoded_len = String.length(encoded)

    drop = Int.of_float(Math.floor(Float.of_int(pad) / 5.0 * 8.0))
    s1 = String.substring(0, encoded_len-drop, encoded)
    s2 = String.repeat(drop, "=")

    "{s1}{s2}"
  }

  /**
   * Recursively converts binary data into a string.
   */
  function string encode_rec(binary data, int offset, int len, string r) {
    if (offset == len) {
      r;
    } else {
      // convert bytes [offset, offset+4] into bits
      bytes = Binary.create(8)
      Binary.add_fill(bytes, 3, 0)
      Binary.add_binary(bytes, Binary.get_binary(data, offset, 5))

      t = bytes_to_string_rec(Binary.get_uint64_be(bytes, 0), 35, "")
      encode_rec(data, offset+5, len, "{r}{t}")
    }
  }

  /**
   * Takes a string of 5 bytes and converts it into a string.
   */
  function string bytes_to_string_rec(int64 bytes, int offset, string r) {
    // convert bits [offset, offset+4] into a character
    t = Int64.logand(Int64.shift_right(bytes, offset), Int64.of_int(31))

    c = int_to_char(Int64.to_int(t))

    if (offset == 0) {
      "{r}{c}";
    } else {
      bytes_to_string_rec(bytes, offset-5, "{r}{c}")
    }
  }

  function string int_to_char(int i) {
    String.substring(i, 1, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
  }
}


