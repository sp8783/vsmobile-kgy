# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "sortablejs", to: "https://cdn.jsdelivr.net/npm/sortablejs@1.15.4/+esm"
pin "tom-select", to: "https://cdn.jsdelivr.net/npm/tom-select@2.4.3/dist/esm/tom-select.complete.js"
# tom-select.complete.js が裸 specifier で import する依存（未pinだと application.js ごと失敗し Stimulus 全滅）
pin "@orchidjs/sifter", to: "https://cdn.jsdelivr.net/npm/@orchidjs/sifter@1.1.0/+esm"
pin "@orchidjs/unicode-variants", to: "https://cdn.jsdelivr.net/npm/@orchidjs/unicode-variants@1.1.0/+esm"
pin "@rails/actioncable", to: "@rails--actioncable.js" # @8.1.100
