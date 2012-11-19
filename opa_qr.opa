import stdlib.crypto
import stdlib.themes.bootstrap

/**
 * A piece of code to demonstrate how to use TOTP in Opa.
 *
 * Note: for added security, it might be a good idea
 * to keep track of which value was last used for each
 * token (i.e. synchronize clocks).
 *
 * @author Alok Menghrajani <alok@fb.com>
 */

type token =
  {
    binary key,
    int interval
  }

database opa_qr {
  int /next_id = 0
  intmap(token) /tokens
}

network_tokens = Network.network(int) (Network.cloud("tokens"))

function ready(_) {
  render_tokens(0)
  gen_qr()
}

function gen_qr() {
  r = Random.string(10) // todo: improve this
  b32 = Base32.encode(binary_of_string(r))
  b64 = Crypto.Base64.encode(binary_of_string(r))

  t = "otpauth://totp/alok@admin.ch?secret={b32}"
  x = Qrcode.get_code(t)
  Dom.set_attribute_unsafe(#qr_output, "src", x)

  // make the output nicer
  s = "{String.substring(0, 4, b32)}-{String.substring(4, 4, b32)}-{String.substring(8, 4, b32)}-{String.substring(12, 4, b32)}"
  #b32_output = s
  #b64_output = b64
}

function int floor2(float n) {
  Int.of_float(Math.floor(n))
}

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

function binary sha1(binary data) {
  Binary.trim(data)
  Crypto.Hash.sha1(data)
}

function binary hash_hmac_sha1(binary key, binary message) {
  block_size = 64
  key = if (Binary.length(key) > block_size) {
    sha1(key)
  } else {
    n_padding = block_size - Binary.length(key)
    Binary.add_fill(key, n_padding, 0)
    key
  }

  o_key_pad = Binary.create(0)
  hash_hmac_xor(key, 0x5c, o_key_pad, 0)
  o_key_pad = Binary.get_binary(o_key_pad, 0, block_size)

  i_key_pad = Binary.create(0)
  hash_hmac_xor(key, 0x36, i_key_pad, 0)
  i_key_pad = Binary.get_binary(i_key_pad, 0, block_size)

  Binary.add_binary(i_key_pad, message)
  h1 = sha1(i_key_pad)

  Binary.add_binary(o_key_pad, h1)
  sha1(o_key_pad)
}

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

function bool validation_rec(int input, binary secret, t1, t2) {
  data = Binary.create(0)
  Binary.add_uint64_be(data, Int64.of_int(t1))

  hash = hash_hmac_sha1(secret, data)

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

function remove_token(int id) {
  Db.remove(@/opa_qr/tokens[id])
  Network.broadcast(0, network_tokens)
}

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

function add_soft_token(_) {
  v = Crypto.Base64.decode(Dom.get_text(#b64_output))
  token = {key: v, interval: 30}
  /opa_qr/next_id++
  /opa_qr/tokens[/opa_qr/next_id] <- token

  // generate a new token
  gen_qr()
  Network.broadcast(0, network_tokens)
}

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
