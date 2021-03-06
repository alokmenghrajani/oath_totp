import stdlib.crypto
import stdlib.themes.bootstrap

/**
 * A piece of code to demonstrate how to use TOTP in Opa.
 *
 * Note: if you are going to use this in a real system, you might want
 * to keep track of which tokens was last used (i.e. synchronize clocks)
 *
 * @author Alok Menghrajani <alok@fb.com>
 *
 * License
 * http://www.opensource.org/licenses/mit-license.php
 */

// for now, token is a simple type. In the future, it might make sense
// to define token as an abstract type and keep all token manipulation
// code in a module (i.e. encapsulate the data).
// we also need to make sure that we never leak the token in js!
type token =
  {
    binary key,
    int interval
  }

// i'm lazy to figure out how to append an element to an intmap, so
// i'm just going to keep track of next_id.
database opa_qr {
  int /next_id = 0
  intmap(token) /tokens
}

// networks help keep the code clean. They also help have nicer demos.
network_tokens = Network.network(int) (Network.cloud("tokens"))

/**
 * Called when the page is loaded.
 */
function ready(_) {
  render_tokens(0)
  gen_qr()
}

/**
 * Creates a new qr code. Uses the Qrcode binding.
 */
function gen_qr() {
  r = Random.string(10) // todo: improve this
  b32 = Base32.encode(binary_of_string(r))
  b64 = Crypto.Base64.encode(binary_of_string(r))

  // demo is the username. You should use the actual username here.
  t = "otpauth://totp/demo?secret={b32}"
  x = Qrcode.get_code(t)
  Dom.set_attribute_unsafe(#qr_output, "src", x)

  // make the output nicer
  s = String.of_list(function(e){e}, "-", str_chunk(b32, 4))
  #b32_output = s
  #b64_output = b64
}

/**
 * Splits a string into chunks of size chunk_size
 *
 * If the string's length is not a multiple of n, the last element
 * will be smaller than n.
 */
function list(string) str_chunk(string input, int chunk_size) {
  recursive function list(string) f(string input, list(string) r) {
    len = String.length(input)
    if (len == 0) {
      r;
    } else {
      n = Int.min(len, chunk_size)
      f(String.substring(n, len - n, input), List.cons(String.substring(0, n, input), r))
    }
  }
  List.rev(f(input, []))
}

/**
 * The stdlib's floor returns a float. I find this annoying, hope
 * someone fixes things in the future...
 */
function int floor2(float n) {
  Int.of_float(Math.floor(n))
}

/**
 * Recusrive function used to xor every byte in data with byte.
 * Called from hash_hmac_sha1.
 */
function hash_hmac_xor(binary data, int byte, binary out, int offset) {
  if (offset < Binary.length(data)) {
    t = Binary.get_uint8(data, offset)
    t = Bitwise.lxor(t, byte)
    Binary.add_uint8(out, t)
    hash_hmac_xor(data, byte, out, offset+1)
  } else {
    void;
  }
}

/**
 * Validates #validation_input by checking every token.
 */
function validation_do(_) {
  input = Int.of_string(Dom.get_value(#validation_input))
  time = Date.in_milliseconds(Date.now())

  res = IntMap.fold(
    function(id, token, r) {
      match (r) {
        case {some: _}: r
        case {none}:
          t = floor2(Float.of_int(time) / (1000.0 * Float.of_int(token.interval)))
          if (validation_rec(input, token.key, t-5, t+5)) {
            {some: id}
          } else {
            {none}
          }
      }
    },
    /opa_qr/tokens,
    {none}
  )

  match (res) {
    case {some: id}:
      Dom.remove_class(#validation_group, "error")
      #validation_output = "OK (matched {id})"
    case {none}:
      Dom.add_class(#validation_group, "error")
      #validation_output = "Sorry, invalid value"
  }
  Dom.set_value(#validation_input, "")
}

/**
 * Recursively validate a token by looking at the time offsets from
 * t1 to t2.
 *
 * Returns true if the input is correct, false otherwise.
 */
function bool validation_rec(int input, binary secret, t1, t2) {
  data = Binary.create(0)
  Binary.add_uint64_be(data, Int64.of_int(t1))

  hash = Crypto.HMAC.sha1(secret, data)

  offset = Bitwise.land(Binary.get_uint8(hash, 19), 0x0f)
  e1 = Bitwise.land(Binary.get_uint8(hash, offset), 0x7f)
  e2 = Binary.get_uint8(hash, offset+1)
  e3 = Binary.get_uint8(hash, offset+2)
  e4 = Binary.get_uint8(hash, offset+3)

  ee1 = Bitwise.lsl(e1, 24)
  ee2 = Bitwise.lsl(e2, 16)
  ee3 = Bitwise.lsl(e3, 8)
  ee4 = e4

  bin_code = Bitwise.lor(ee1, Bitwise.lor(ee2, Bitwise.lor(ee3, ee4)))

  code = mod(bin_code, 1000000)

  if (input == code) {
    true;
  } else if (t1 == t2) {
    false;
  } else {
    validation_rec(input, secret, t1+1, t2)
  }
}

/**
 * Removes a token from the db.
 */
function remove_token(int id) {
  Db.remove(@/opa_qr/tokens[id])
  Network.broadcast(0, network_tokens)
}

/**
 * Renders the list of tokens in the db.
 */
function render_tokens(_) {
  #tokens_list = if (IntMap.is_empty(/opa_qr/tokens)) {
    <>No tokens</>;
  } else {
    t = IntMap.fold(
      function(id, token, r) {
        t = if (token.interval == 30) {
          "soft token";
        } else {
          "physical token";
        }
        r <+>
         <li>token id: {id} (type: {t})
           <button onclick={function(_){remove_token(id)}} class="close" type="button">×</button>
         </li>
      },
      /opa_qr/tokens,
      <></>
    )
    <ul class="unstyled">{t}</ul>
  }
}

/**
 * Adds a software based token.
 *
 * Note: the 30 seconds interval is hardcoded.
 */
function add_soft_token(_) {
  v = Crypto.Base64.decode(Dom.get_text(#b64_output))
  token = {key: v, interval: 30}
  /opa_qr/next_id++
  /opa_qr/tokens[/opa_qr/next_id] <- token

  // generate a new token
  gen_qr()
  Network.broadcast(0, network_tokens)
}

/**
 * Adds a physical token.
 *
 * Note: the 60 seconds interval is hardcoded, because that's how my token works.
 */
function add_physical_token(_) {
  v = Crypto.Base64.decode(Dom.get_value(#input_key))
  if (Binary.length(v) != 20) {
    // TOTP keys are 20 bytes in size
    Dom.add_class(#input_key_group, "error")
    #input_key_error = "Sorry, invalid input"
  } else {
    token = {key: v, interval: 60}
    /opa_qr/next_id++
    /opa_qr/tokens[/opa_qr/next_id] <- token

    Dom.set_value(#input_key, "")
    Network.broadcast(0, network_tokens)
    Dom.remove_class(#input_key_group, "error")
    #input_key_error = ""
  }
}

/**
 * Main and only page rendering code.
 */
function page() {
  Network.add_callback(render_tokens, network_tokens)

  <>
    <div class="navbar navbar-inverse navbar-fixed-top">
      <div class="navbar-inner">
        <div class="container">
          <a class="brand">Fun With TOTP</a>
          <ul class="nav">
            <li><a href="#list">List tokens</a></li>
            <li><a href="#create">Add token</a></li>
            <li><a href="#validate">Check token</a></li>
            <li></li>
          </ul>
        </div>
      </div>
    </div>

    <div class="container" style="padding-top: 65px" onready={ready}>
      <div class="hero-unit">
        <h1>Fun With TOTP</h1>
        <p>
          The purpose of this page is to show you that using
          two-factor authentication in your web apps is very easy.
        </p>
        <p>
          You can use software-based tokens (e.g. running on
          your Android or iPhone devices).
        </p>
        <p>
          For added security, you may decide to use physical tokens.
        </p>
      </div>

      <section id="list">
        <div class="page-header">
          <h1>List of tokens</h1>
        </div>
        <p>
          This is the list of tokens, which have been added to the database.
          In a real world application, tokens would be mapped to user accounts.
        </p>
        <div style="border: 1px solid #DDDDDD; border-radius: 4px 4px 4px 4px; padding: 3px 7px" id=#tokens_list/>
      </section>

      <section id="create">
        <div class="page-header">
          <h1>Add a token</h1>
        </div>
        <p>
          TOTP is a standard. It can be implemented in software or hardware.
        </p>

        <h2>Software based token</h2>
        <ol>
          <li>Scan this image or manually type the code in your authenticator.</li>
          <li>Click on save token</li>
        </ol>
        <img id=#qr_output/>
        <div style="margin-left: 16px">
          <div id=#b32_output/>
          <div id=#b64_output style="display: none"/>
          <p><button class="btn btn-primary" onclick={add_soft_token}>Save token</button></p>
        </div>

        <h2>Physical token</h2>
        <p>
          Please provide the seed, which was given to you with your physical token.
        </p>
        <div id=#input_key_group class="control-group form-horizontal">
          <label class="control-label">Base64 encoded key</label>
          <div class="controls">
            <input id=#input_key class="input-xlarge" type="text" placeholder="e.g. JJsK5VOlwP6LjyyoQ1ek06OO3Gz"/>
            <span id=#input_key_error class="help-inline"/>
          </div>
        </div>
        <div class="control-group form-horizontal">
          <div class="controls">
            <button class="btn btn-primary" onclick={add_physical_token}>Save token</button>
          </div>
        </div>
      </section>

      <section id="validate">
        <div class="page-header">
          <h1>Check a token</h1>
        </div>
        <p>
          Token validation can be done conditionally. Depending on the user's location, time of day, system
          being accessed, you can require a token or not. You can also require physical tokens for
          the most critical systems, while allowing a physical or software token for other systems.
        </p>
        <div id=#validation_group class="control-group form-horizontal">
          <label class="control-label">Token value</label>
          <div class="controls">
            <input id=#validation_input class="input-mini" type="text" onnewline={validation_do}/>
            <button class="btn btn-primary" onclick={validation_do}>Check</button>
            <span id=#validation_output class="help-inline"/>
          </div>
        </div>
      </section>
    </div>
    <div style="padding-top: 500px"> </div>
  </>
}

Server.start(Server.http, {{title: "Fun With TOTP",  page: page}})
