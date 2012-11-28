/**
 * Base32 unittest, based on the test vectors from rfc4648
 *
 * Running: make test
 *
 * @author Alok Menghrajani
 */

function run_tests() {
  t = Test.begin()

  t = Test.expect_equals(t, "empty string",
    Base32.encode(binary_of_string("")),
    ""
  )

  t = Test.expect_equals(t, "one character",
    Base32.encode(binary_of_string("f")),
    "MY======"
  )

  t = Test.expect_equals(t, "two characters",
    Base32.encode(binary_of_string("fo")),
    "MZXQ===="
  )

  t = Test.expect_equals(t, "three characters",
    Base32.encode(binary_of_string("foo")),
    "MZXW6==="
  )

  t = Test.expect_equals(t, "four characters",
    Base32.encode(binary_of_string("foob")),
    "MZXW6YQ="
  )

  t = Test.expect_equals(t, "five characters",
    Base32.encode(binary_of_string("fooba")),
    "MZXW6YTB"
  )

  t = Test.expect_equals(t, "six characters",
    Base32.encode(binary_of_string("foobar")),
    "MZXW6YTBOI======"
  )

  Test.end(t)
}
run_tests()
