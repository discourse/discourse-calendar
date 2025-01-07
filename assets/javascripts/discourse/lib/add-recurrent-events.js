import DiscoursePostEventEvent from "../models/discourse-post-event-event";

export default function addRecurrentEvents(events) {
  return events.flatMap((event) => {
    const upcomingEvents =
      event.upcomingDates?.map((upcomingDate) =>
        DiscoursePostEventEvent.create({
          name: event.name,
          post: event.post,
          category_id: event.categoryId,
          starts_at: upcomingDate.starts_at,
          ends_at: upcomingDate.ends_at,
        })
      ) || [];

    return [event, ...upcomingEvents];
  });
}
