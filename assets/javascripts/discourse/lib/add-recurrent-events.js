export default function addRecurrentEvents(events) {
  return events.flatMap((event) => {
    const upcomingEvents =
      event.upcoming_dates?.map((upcomingDate) => ({
        ...event,
        starts_at: upcomingDate.starts_at,
        ends_at: upcomingDate.ends_at,
        upcoming_dates: [],
      })) || [];

    return [event, ...upcomingEvents];
  });
}
