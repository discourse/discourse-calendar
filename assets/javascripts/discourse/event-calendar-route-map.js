export default {
    resource: "discovery",
    map() {
      this.route('calendarCategory', { path: "/c/*category_slug_path_with_id/l/calendar" });
    },
  };
  