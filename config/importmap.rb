# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "nostr-tools", to: "https://ga.jspm.io/npm:nostr-tools@1.12.1/lib/esm/nostr.mjs"
pin "@noble/curves/abstract/modular", to: "https://ga.jspm.io/npm:@noble/curves@1.0.0/esm/abstract/modular.js"
pin "@noble/curves/secp256k1", to: "https://ga.jspm.io/npm:@noble/curves@1.0.0/esm/secp256k1.js"
pin "@noble/hashes/_assert", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/_assert.js"
pin "@noble/hashes/crypto", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/crypto.js"
pin "@noble/hashes/hmac", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/hmac.js"
pin "@noble/hashes/pbkdf2", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/pbkdf2.js"
pin "@noble/hashes/ripemd160", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/ripemd160.js"
pin "@noble/hashes/sha256", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/sha256.js"
pin "@noble/hashes/sha512", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/sha512.js"
pin "@noble/hashes/utils", to: "https://ga.jspm.io/npm:@noble/hashes@1.3.0/esm/utils.js"
pin "@scure/base", to: "https://ga.jspm.io/npm:@scure/base@1.1.1/lib/esm/index.js"
pin "@scure/bip32", to: "https://ga.jspm.io/npm:@scure/bip32@1.3.0/lib/esm/index.js"
pin "@scure/bip39", to: "https://ga.jspm.io/npm:@scure/bip39@1.2.0/index.js"
pin "@scure/bip39/wordlists/english.js", to: "https://ga.jspm.io/npm:@scure/bip39@1.2.0/wordlists/english.js"
