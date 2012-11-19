OATH TOTP in Opa
================
OATH is a standard for two factor authentication (i.e. RSA thingy which generates a unique code every
minute). The purpose of this code is to demonstrate how to implement things in Opa.

I also implemented Google's KeyUriFormat, so everything is easy with the Google Authenticator app.

Note: if you are going to use this in a real system, you
might want to keep track of which tokens was last used
(i.e. synchronize clocks)


license
=======
http://www.opensource.org/licenses/mit-license.php


links
=====
- http://tools.ietf.org/html/rfc6238
- http://opalang.org/
- http://code.google.com/p/google-authenticator/
- http://www.gooze.eu/otp-c200-token-time-based-h3-casing-1-unit


screenshots
===========
![](https://raw.github.com/alokmenghrajani/oath_totp/master/screenshot.png "")
![](https://raw.github.com/alokmenghrajani/oath_totp/master/google_authenticator.jpg "")
![](https://raw.github.com/alokmenghrajani/oath_totp/master/otp_c200.png "")