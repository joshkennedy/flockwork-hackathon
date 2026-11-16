import "@hotwired/turbo-rails"
import { application } from "controllers/application"
import PublicHeaderController from "controllers/public_header_controller"
import RevealController from "controllers/reveal_controller"
import WashController from "controllers/wash_controller"

application.register("public-header", PublicHeaderController)
application.register("reveal", RevealController)
application.register("wash", WashController)
