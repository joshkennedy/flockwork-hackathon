# Pin npm packages by running ./bin/importmap

pin "application", preload: "application"
pin "marketing", preload: "marketing"
pin "public", preload: "public"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: %w[application marketing public]
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: %w[application marketing public]
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: "application"
pin_all_from "app/javascript/controllers", under: "controllers", preload: false
pin "trix", preload: "application"
pin "@rails/actiontext", to: "actiontext.esm.js", preload: "application"
pin "pdfjs-dist", to: "pdf.min.js", preload: "application"
pin "ding", to: "ding.js", preload: %w[application public]
