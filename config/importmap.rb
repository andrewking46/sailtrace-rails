# Pin npm packages by running ./bin/importmap

pin "application"
pin "mapbox-gl" # @3.1.2
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "process" # @2.0.1
