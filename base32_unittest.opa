/**
 * Base32 unittest, based on the test vectors from rfc4648
 *
 * Running: make test
 *
 * @author Alok Menghrajani
 */

function expect_encode(Test.result res, string test_name, string s, string expected) {
  Test.expect_equals(res, test_name, Base32.encode(binary_of_string(s)), expected)
}

function expect_decode(Test.result res, string test_name, string s, string expected) {
  match(Base32.decode(s)) {
    case {none}:
      extra_message = "(expecting {expected}, got none)"
      Test.fail(res, test_name, extra_message)
    case {~some}:
      Test.expect_equals(res, test_name, string_of_binary(some), expected)
  }
}

function run_tests() {
  t = Test.begin()

  t = expect_encode(t, "empty string", "", "")
  t = expect_decode(t, "empty string", "", "")

  t = expect_encode(t, "one character", "f", "MY======")
  t = expect_decode(t, "one character", "MY======", "f")

  t = expect_encode(t, "two characters", "fo", "MZXQ====")
  t = expect_decode(t, "two characters", "MZXQ====", "fo")

  t = expect_encode(t, "three characters", "foo", "MZXW6===")
  t = expect_decode(t, "three characters", "MZXW6===", "foo")

  t = expect_encode(t, "four characters", "foob", "MZXW6YQ=")
  t = expect_decode(t, "four characters", "MZXW6YQ=", "foob")

  t = expect_encode(t, "five characters", "fooba", "MZXW6YTB")
  t = expect_decode(t, "five characters", "MZXW6YTB", "fooba")

  t = expect_encode(t, "six characters", "foobar", "MZXW6YTBOI======")
  t = expect_decode(t, "six characters", "MZXW6YTBOI======", "foobar")

  Test.end(t)
}
run_tests()
