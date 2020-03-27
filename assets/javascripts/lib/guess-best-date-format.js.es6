export default function guessDateFormat(startsAt, endsAt) {
  let format;
  if (
    startsAt.hours() > 0 ||
    startsAt.minutes() > 0 ||
    (endsAt && (moment(endsAt).hours() > 0 || moment(endsAt).minutes() > 0))
  ) {
    format = "LLL";
  } else {
    format = "LL";
  }

  return format;
}
