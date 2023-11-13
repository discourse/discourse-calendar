import Component from "@glimmer/component";
import EventDate from "../../components/event-date";

export default class EventDateContainer extends Component {
    <template><EventDate @topic={{@outletArgs.topic}} /></template>
}