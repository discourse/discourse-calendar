export default function() {
  this.route("upcoming-events", { path: "/upcoming-events" }, function() {
    this.route("index", { path: "/" });
  });
}
