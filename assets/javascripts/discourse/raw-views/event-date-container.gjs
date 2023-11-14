import EmberObject from "@ember/object";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";
import EventDate from "../components/event-date";

export default class extends EmberObject {
    get html() {
        return rawRenderGlimmer(
            this,
            "span.event-date-container-wrapper",
            <template><EventDate @topic={{@data.topic}} /></template>,
            { topic: this.topic }
        );
    }
}
