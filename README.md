# docker-keys

All-in-one key management image (Alpine-based): SSH, PGP/GnuPG, age, paper backups, QR encode/decode, YubiKey management.

## Tools inside

| Area | Tools |
|---|---|
| SSH | `ssh-keygen`, `ssh-agent`, `ssh-add`, `ssh` (openssh-client) |
| PGP | `gpg`, `gpg-agent`, `scdaemon` (gnupg), `paperkey` |
| age | `age`, `age-keygen`, `age-plugin-yubikey` (v0.5.0, compiled from source in-builder, not in Alpine repos) |
| Paper backup | `paperkey` (GPG secret-key to printable text, and back) |
| QR code | `qrencode` (key/text/file to QR PNG/SVG/ANSI), `zbarimg` (QR photo back to data) |
| YubiKey | `ykman` (yubikey-manager: OTP, FIDO2, PIV, OATH), `yubico-piv-tool`, `opensc` (`pkcs11-tool`, `piv-tool`), `ykpersonalize`, `pcscd`/`ccid` stack |
| Helpers | `openssl`, `argon2`, `jq`, `git`, `bash`, `pinentry` |

## Build and run

```sh
docker build -t docker-keys .
docker run --rm -it -v "$PWD/work:/work" docker-keys

# Persist GPG/SSH homes between runs:
docker run --rm -it -v keys-gnupg:/root/.gnupg -v keys-ssh:/root/.ssh docker-keys

# YubiKey USB passthrough (Linux). --privileged plus the host udev socket are
# required: without /run/udev, pcscd misattributes the YubiKey's USB interfaces
# and the CCID reader never initializes. pcscd is auto-started by the entrypoint.
docker run --rm -it --privileged -v /run/udev:/run/udev docker-keys

# Alternative: use the host's pcscd instead of the in-container one.
# Start pcscd on the host (needs the CCID driver installed there), then:
docker run --rm -it --device=/dev/bus/usb -v /run/pcscd:/run/pcscd docker-keys
```

## Use cases

### SSH
```sh
ssh-keygen -t ed25519 -C "me@example.com"
ssh-keygen -t ed25519-sk -O resident -O verify-required   # FIDO2 / YubiKey-backed
eval $(ssh-agent); ssh-add ~/.ssh/id_ed25519
ssh-keygen -y -f ~/.ssh/id_ed25519                       # public key from private
ssh-keygen -p -f ~/.ssh/id_ed25519                       # change passphrase
```

### PGP / GnuPG
```sh
gpg --full-generate-key
gpg --list-secret-keys --keyid-format=long
gpg --armor --export me@example.com > public.asc
gpg --armor --export-secret-keys me@example.com > secret.asc
gpg --encrypt --recipient me@example.com -o secret.txt.gpg secret.txt
gpg --decrypt -o secret.txt secret.txt.gpg
gpg --detach-sign -a file.txt && gpg --verify file.txt.asc
```

### age
```sh
age-keygen -o age-key.txt
age -r age1ql3z7hj432v2jl2z8alunwwun8hm4s4h6lx5a6x0p0rwl9u9ah73q3qy9g7 file.txt > file.txt.age
age --decrypt -i age-key.txt -o file.txt file.txt.age
age --encrypt -R recipients.txt -o file.txt.age file.txt   # multiple recipients
```

### age + YubiKey
```sh
age-plugin-yubikey --generate --name "backup-key" | age --encrypt -r AGE-PLUGIN-YUBIKEY-... -o file.age file.txt
age --decrypt -i <identity-file> -o file.txt file.age   # touch YubiKey when it blinks
```

### Paper backup (paperkey)
```sh
gpg --export-secret-keys me@example.com | paperkey --output secret.txt
paperkey --pubring public.asc --secrets secret.txt | gpg --import   # restore
# Print secret.txt, store offline; also works well piped into qrencode below.
```

### Password hashing (argon2)
```sh
echo -n 'correct-horse' | argon2 somesalt -t 2 -m 16 -p 1 -l 24   # Argon2i PHC hash
openssl rand -base64 16 | tee salt.txt                            # fresh salt per password
```

### Key to QR code and back
```sh
qrencode -o age-key.png -s 10 < age-key.txt
qrencode -t ANSIUTF8 < age-key.txt                        # show in terminal, scan with phone
zbarimg --raw age-key.png > restored-key.txt              # photo/scan back to data
diff age-key.txt restored-key.txt && echo RESTORED-OK
```

### YubiKey management
```sh
# No "PC/SC not available" warning should appear; without hardware you get
# "No YubiKey detected!" which is expected. ykman openpgp needs no extra
# package: it ships with yubikey-manager, it needs CCID via pcscd.
ykman info
ykman list
ykman otp info / ykman fido credentials list / ykman oath accounts list
ykman piv info; yubico-piv-tool -a status
pkcs11-tool --module /usr/lib/libykcs11.so -L -O
ykpersonalize -m82 -oauthtimeout -ochal-resp -ochal-hmac   # program YubiOTP slots (resets slot!)

# OpenPGP applet over CCID:
ykman openpgp info
```

Verified working with a YubiKey 5C NFC (firmware 5.7.1): `ykman openpgp info`
returns the full applet status over in-container CCID.

If `ykman openpgp info` says "Failed to connect" while `ykman list` sees the
key, the CCID interface is busy or misattributed: make sure you passed both
`--privileged` and `-v /run/udev:/run/udev`, and that no host-side pcscd or
other process holds the device (`fuser /dev/bus/usb/*/*`). Stale state from
repeated failed claims can wedge the enumeration ("Can't claim interface:
LIBUSB_ERROR_BUSY"); fix by unplugging the key, confirming it is gone from
the bus with no holders, then re-plugging and retrying in a fresh container.

## Notes

- Alpine base keeps the image small; `age-plugin-yubikey` has no Alpine package, so the Dockerfile fetches the upstream static release binary.
- `zbarimg` decodes QR/barcodes from image files; live camera scanning (`zbarcam`) needs a video device passed through.
- Never commit real secret keys; mount them at runtime and keep paper/QR printouts offline.
