all:
	rm -fr qrcode.opp
	opa-plugin-builder --js-validator-off qrcode.js -o qrcode.opp
	opa qrcode.opp qrcode.opa base32.opa opa_qr.opa --

clean:
	rm -Rf *~ *.exe *.log _build/ _tracks/ *.opp opa_qr_depends/ opa_qr.js base32_unittest.js package.json

test:
	opa base32.opa utils_test.opa base32_unittest.opa --
