/**
 * Base32 library for Opa.
 *
 * See rfc4648: http://tools.ietf.org/html/rfc4648
 *
 * Note: this module supports a single alphabet. It's pretty
 *       easy to adapt it for other base32 flavors.
 *
 */
module Base32 {

  public function string encode(binary data) {
    len = Binary.length(data)

    // make a copy of the data, since operations on Binary
    // mutate the buffer
    copy = Binary.get_binary(data, 0, len)

    // pad the data if the length is not a multiple of 5
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

  public function option(binary) decode(string data) {
    // check that the string is multiple of 8
    encoded_len = String.length(data)

    if (mod(encoded_len, 8) != 0) {
      {none}
    } else if (is_valid(data) == false) {
      {none}
    } else {
      buf = Binary.create(0)
      t = decode_rec(data, 0, encoded_len, buf)
      Binary.trim(t)

      // count number of = at the end of the string
      if (encoded_len > 0) {
        n = encoded_len - get_num_padding_rec(data, 0)
        if (n > 0) {
          Binary.resize(t, n * 5 / 8)
        }
      }
      {some: t}
    }
  }

  /**
   * Recursively converts binary data into a string.
   */
  private function string encode_rec(binary data, int offset, int len, string r) {
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
   * Recursively converts string into binary data.
   */
  private function binary decode_rec(string data, int offset, int len, binary buf) {
    if (offset == len) {
      buf;
    } else {
      // convert string [offset, offset+7] into bits
      s = String.substring(offset, 8, data)
      n = string_to_bytes_rec(s, 0, Int64.of_int(0))

      t = Binary.create(8)
      Binary.add_uint64_be(t, n)
      Binary.add_binary(buf, Binary.get_binary(t, 3, 5))

      decode_rec(data, offset+8, len, buf)
    }
  }

  /**
   * Takes a string of 5 bytes and converts it into a string.
   */
  private function string bytes_to_string_rec(int64 bytes, int offset, string r) {
    // convert bits [offset, offset+4] into a character
    t = Int64.logand(Int64.shift_right(bytes, offset), Int64.of_int(31))

    c = int_to_char(Int64.to_int(t))

    if (offset == 0) {
      "{r}{c}";
    } else {
      bytes_to_string_rec(bytes, offset-5, "{r}{c}")
    }
  }

  /**
   * Takes a string of 8 bytes and converts it into an int64.
   */
  private function int64 string_to_bytes_rec(string data, int offset, int64 r) {
    if (offset == 8) {
      r;
    } else {
      c = String.substring(offset, 1, data)
      t = Int64.logor(Int64.shift_left(r, 5), Int64.of_int(Option.get(char_to_int(c))))
      string_to_bytes_rec(data, offset+1, t)
    }
  }

  /**
   * Converts an int into a char. This probably isn't the most efficient
   * implementation, but I don't really care.
   */
  private function string int_to_char(int i) {
    String.substring(i, 1, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
  }

  /**
   * Converts a character into an int. Again, this isn't the most
   * efficient implementation, but I don't really care.
   */
  private function option(int) char_to_int(string c) {
    if (c == "=") {
      {some: 0}
    } else {
      String.index(c, "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    }
  }

  private function get_num_padding_rec(string data, int n) {
    if (String.substring(String.length(data)-1-n, 1, data) == "=") {
      get_num_padding_rec(data, n+1)
    } else {
      n;
    }
  }

  /**
   * Checks if a string contains all valid characters by
   * folding over each character.
   *
   * TODO: check that = is only at the end, max 6 of them
   */
  private function is_valid(string data) {
    String.fold(
      function(string c, r) {
        r && Option.is_some(char_to_int(c))
      },
      data,
      true
    )
  }
}


