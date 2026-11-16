import "@hotwired/turbo-rails"
import { application } from "controllers/application"
import SelectController from "controllers/select_controller"
import SlotLandingController from "controllers/slot_landing_controller"
import ToastsController from "controllers/toasts_controller"

application.register("select", SelectController)
application.register("slot-landing", SlotLandingController)
application.register("toasts", ToastsController)
