#!/bin/bash
# Add Forge's public key to the server

FORGE_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLSZ5GLxsGlDEZ53fbQHdLAClmebU9m7LT4PUmVbveQQxB/eqjm/p5XNQEg97w1K9OMXBu1hbqNaKlRFbxEAX1DmxsmSDApJ1KuvFZZza8iF1wFupurquQdrPanSVOokEauovOvRoavWGSRzIXGzQvRZHTbjwibsbxWg2Xv6KQGvOEV9VAhyZdM87mG68MjxW1BKXYeAAZltBB8NhXXf+2bw0X2D97Bq6NcvSkRd4mp4lheNPl2zT5ABcsvp1DZZ3ToxZWfFXvGTQoPXWn5nsLa2HJTcYahallIV73c2AATg03j3f+292zZCL8uQayyhSUQhbTUNcsHznHzSBt6MWP6Wmmim89BTSgRJX7hvpArqJgT4Ru7KfSTrC8C9yFGWAo6Ay/keWQmy23sH+rDvhQDDt+JplBwJAHEgjH4NQDGBXs679c4DDCEfIJxYdsDzHQpwPMFPBUnXXDFJKMJCrixFJFbf/DRtnBN8Cpjx1i5tWyCbED3meVxP3jey3zwVCCJK21xgFB0Ffl1c7UdWuDK/Up6Hvxk29kRlXWvrIyVGDsd4zzwhetF3i3EAvtMqYvtpvSv+pDkib3soSHkVy+vwXsrn+dmIhl9amFrbT7FexKbJM8Vt1DE2PNUdcyEFEEAH2GrDi31YnX7Mc4v5nirhAJKopI+aPMfgNLQ3Wddw== worker@forge.laravel.com"

echo "Adding Forge's public key to authorized_keys..."
echo "$FORGE_PUBLIC_KEY" >> ~/.ssh/authorized_keys

echo "Setting correct permissions..."
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

echo "✅ Forge public key added successfully!"
echo ""
echo "Forge should now be able to connect to this server."
