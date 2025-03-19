import DiscoursePostEventEvent from "../models/discourse-post-event-event";

export default async function addRecurrentEvents(eventsPromise) {
  try {
    const events = await eventsPromise;

    if (!Array.isArray(events)) {
      console.error("Expected an array but received:", events);
      return [];
    }

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
  } catch (error) {
    console.error("Failed to retrieve events:", error);
    return [];
  }
}
