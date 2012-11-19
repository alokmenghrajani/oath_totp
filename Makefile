all:
	rm -fr qrcode.opp
	opa-plugin-builder --js-validator-off qrcode.js -o qrcode.opp
	opa qrcode.opp qrcode.opa base32.opa opa_qr.opa --

