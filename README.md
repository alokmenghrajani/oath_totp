OATH TOTP in Opa
================
OATH is a standard for two factor authentication (i.e. RSA thingy which generates a unique code every
minute). The purpose of this code is to demonstrate how to implement things in Opa.

I also implemented Google's KeyUriFormat, so everything is easy with the Google Authenticator app.

Note: if you are going to use this in a real system, you
might want to keep track of which tokens was last used
(i.e. synchronize clocks)

![](http://pixlpaste.s3-website-us-east-1.amazonaws.com/pixels/R2k3Au "")

license
=======
http://www.opensource.org/licenses/mit-license.php


links
=====
- http://tools.ietf.org/html/rfc6238
- http://opalang.org/
- http://code.google.com/p/google-authenticator/
