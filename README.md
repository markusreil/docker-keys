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
| Helpers | `openssl`, `jq`, `git`, `bash`, `pinentry` |

## Build and run

```sh
docker build -t docker-keys .
docker run --rm -it -v "$PWD/work:/work" docker-keys

# Persist GPG/SSH homes between runs:
docker run --rm -it -v keys-gnupg:/root/.gnupg -v keys-ssh:/root/.ssh docker-keys

# YubiKey USB passthrough (Linux):
docker run --rm -it --device=/dev/bus/usb --device=/dev/hidraw9 -v /run/pcscd:/run/pcscd docker-keys
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

### Key to QR code and back
```sh
qrencode -o age-key.png -s 10 < age-key.txt
qrencode -t ANSIUTF8 < age-key.txt                        # show in terminal, scan with phone
zbarimg --raw age-key.png > restored-key.txt              # photo/scan back to data
diff age-key.txt restored-key.txt && echo RESTORED-OK
```

### YubiKey management
```sh
ykman info
ykman list
ykman otp info / ykman fido credentials list / ykman oath accounts list
ykman piv info; yubico-piv-tool -a status
pkcs11-tool --module /usr/lib/libykcs11.so -L -O
ykpersonalize -m82 -oauthtimeout -ochal-resp -ochal-hmac   # program YubiOTP slots (resets slot!)
```

## Notes

- Alpine base keeps the image small; `age-plugin-yubikey` has no Alpine package, so the Dockerfile fetches the upstream static release binary.
- `zbarimg` decodes QR/barcodes from image files; live camera scanning (`zbarcam`) needs a video device passed through.
- Never commit real secret keys; mount them at runtime and keep paper/QR printouts offline.
